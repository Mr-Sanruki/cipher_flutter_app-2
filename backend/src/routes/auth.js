const express = require('express');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

const { User } = require('../models/User');
const { Otp } = require('../models/Otp');
const { randomOtp6, sha256 } = require('../lib/crypto');

const authRouter = express.Router();

async function sendOtpEmailWithBrevo({ email, code, ttlSeconds }) {
  const apiKey = String(process.env.BREVO_API_KEY || '').trim();
  const fromEmail = String(process.env.BREVO_FROM_EMAIL || '').trim();
  const fromName = String(process.env.BREVO_FROM_NAME || 'Cipher').trim();
  if (!apiKey) return { ok: false, error: 'BREVO_API_KEY_MISSING' };
  if (!fromEmail) return { ok: false, error: 'BREVO_FROM_EMAIL_MISSING' };

  const resp = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { name: fromName, email: fromEmail },
      to: [{ email }],
      subject: 'Your Cipher login code',
      textContent: `Your Cipher login code is: ${code}. It expires in ${Math.floor(ttlSeconds / 60)} minutes.`,
    }),
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    const lowered = String(text || '').toLowerCase();
    if (resp.status === 401 && lowered.includes('authorised_ips')) {
      return {
        ok: false,
        error: 'BREVO_UNAUTHORIZED_IP',
        status: resp.status,
        details: text,
      };
    }
    return { ok: false, error: 'BREVO_SEND_FAILED', status: resp.status, details: text };
  }

  const data = await resp.json().catch(() => ({}));
  return { ok: true, messageId: data?.messageId, raw: data };
}

async function sendOtpEmailWithResend({ email, code, ttlSeconds }) {
  const apiKey = String(process.env.RESEND_API_KEY || '').trim();
  const from = String(process.env.RESEND_FROM_EMAIL || '').trim();
  if (!apiKey) return { ok: false, error: 'RESEND_API_KEY_MISSING' };
  if (!from) return { ok: false, error: 'RESEND_FROM_EMAIL_MISSING' };

  const resp = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: email,
      subject: 'Your Cipher login code',
      text: `Your Cipher login code is: ${code}. It expires in ${Math.floor(ttlSeconds / 60)} minutes.`,
    }),
  });

  if (!resp.ok) {
    const text = await resp.text().catch(() => '');
    return { ok: false, error: 'RESEND_SEND_FAILED', status: resp.status, details: text };
  }

  const data = await resp.json().catch(() => ({}));
  return { ok: true, id: data?.id, raw: data };
}

async function sendOtpEmailWithSmtp({ email, code, ttlSeconds }) {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 587);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.SMTP_FROM;
  if (!host) return { ok: false, error: 'SMTP_HOST_MISSING' };
  if (!user) return { ok: false, error: 'SMTP_USER_MISSING' };
  if (!pass) return { ok: false, error: 'SMTP_PASS_MISSING' };
  if (!from) return { ok: false, error: 'SMTP_FROM_MISSING' };

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
    connectionTimeout: 15_000,
    greetingTimeout: 15_000,
    socketTimeout: 20_000,
    tls: {
      servername: host,
      rejectUnauthorized: false,
    },
  });

  await transporter.sendMail({
    from,
    to: email,
    subject: 'Your Cipher login code',
    text: `Your Cipher login code is: ${code}. It expires in ${Math.floor(ttlSeconds / 60)} minutes.`,
  });

  return { ok: true };
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function signJwt(user) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error('JWT_SECRET is required');

  return jwt.sign(
    {
      sub: String(user._id),
      email: user.email,
    },
    secret,
    { expiresIn: '30d' }
  );
}

function hashPassword(password) {
  const iterations = 120000;
  const salt = crypto.randomBytes(16).toString('hex');
  const dk = crypto.pbkdf2Sync(password, salt, iterations, 32, 'sha256').toString('hex');
  return `pbkdf2_sha256$${iterations}$${salt}$${dk}`;
}

function verifyPassword(password, passwordHash) {
  const raw = String(passwordHash || '').trim();
  const parts = raw.split('$');
  if (parts.length !== 4) return false;
  const [algo, iterStr, salt, hash] = parts;
  if (algo !== 'pbkdf2_sha256') return false;
  const iterations = Number(iterStr);
  if (!Number.isFinite(iterations) || iterations <= 0) return false;
  if (!salt || !hash) return false;
  const dk = crypto.pbkdf2Sync(String(password), salt, iterations, 32, 'sha256').toString('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(dk, 'hex'), Buffer.from(hash, 'hex'));
  } catch (_) {
    return false;
  }
}

authRouter.post('/register', async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const name = String(req.body?.name || '').trim();
  const password = String(req.body?.password || '');

  if (!email || !email.includes('@')) return res.status(400).json({ error: 'INVALID_EMAIL' });
  if (!name) return res.status(400).json({ error: 'NAME_REQUIRED' });
  if (password.length < 6) return res.status(400).json({ error: 'WEAK_PASSWORD' });

  const existing = await User.findOne({ email }).lean();
  if (existing) return res.status(409).json({ error: 'EMAIL_EXISTS' });

  const passwordHash = hashPassword(password);
  const user = await User.create({ email, name, passwordHash });
  const token = signJwt(user);

  return res.status(201).json({
    token,
    user: {
      id: String(user._id),
      email: user.email,
      name: user.name,
    },
  });
});

authRouter.post('/login', async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const password = String(req.body?.password || '');
  if (!email || !email.includes('@')) return res.status(400).json({ error: 'INVALID_EMAIL' });
  if (!password) return res.status(400).json({ error: 'PASSWORD_REQUIRED' });

  const user = await User.findOne({ email });
  if (!user) return res.status(401).json({ error: 'INVALID_CREDENTIALS' });
  if (!user.passwordHash) return res.status(401).json({ error: 'PASSWORD_NOT_SET' });

  const ok = verifyPassword(password, user.passwordHash);
  if (!ok) return res.status(401).json({ error: 'INVALID_CREDENTIALS' });

  const token = signJwt(user);
  return res.json({
    token,
    user: {
      id: String(user._id),
      email: user.email,
      name: user.name,
    },
  });
});

authRouter.post('/request-otp', async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  if (!email || !email.includes('@')) return res.status(400).json({ error: 'INVALID_EMAIL' });

  const cooldownSeconds = Number(process.env.OTP_RESEND_COOLDOWN_SECONDS || 45);
  const ttlSeconds = Number(process.env.OTP_TTL_SECONDS || 600);

  const existing = await Otp.findOne({ email }).sort({ createdAt: -1 }).lean();
  if (existing) {
    const elapsedMs = Date.now() - new Date(existing.createdAt).getTime();
    if (elapsedMs < cooldownSeconds * 1000) {
      return res.status(429).json({ error: 'OTP_COOLDOWN' });
    }
  }

  const code = randomOtp6();
  const codeHash = sha256(`${email}:${code}`);
  const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

  // eslint-disable-next-line no-console
  console.log('[otp] created', {
    email,
    code,
    codeHashPrefix: codeHash.slice(0, 8),
    expiresAt: expiresAt.toISOString(),
  });

  try {
    const provider = String(process.env.EMAIL_PROVIDER || 'smtp').toLowerCase();
    if (provider === 'brevo') {
      const brevoResult = await sendOtpEmailWithBrevo({ email, code, ttlSeconds });
      if (!brevoResult.ok) {
        // eslint-disable-next-line no-console
        console.error('[brevo] send error:', brevoResult);
        if (String(process.env.RESEND_API_KEY || '').trim() && String(process.env.RESEND_FROM_EMAIL || '').trim()) {
          const resendResult = await sendOtpEmailWithResend({ email, code, ttlSeconds });
          if (!resendResult.ok) {
            // eslint-disable-next-line no-console
            console.error('[resend] fallback send error:', resendResult);
            return res.status(502).json({ error: brevoResult.error, fallbackError: resendResult.error });
          }
          await Otp.create({ email, codeHash, expiresAt });
          return res.json({ ok: true, provider: 'resend' });
        }

        return res.status(502).json({ error: brevoResult.error });
      }

      await Otp.create({ email, codeHash, expiresAt });
      return res.json({ ok: true, provider: 'brevo' });
    }
    if (provider === 'resend') {
      const resendResult = await sendOtpEmailWithResend({ email, code, ttlSeconds });
      if (!resendResult.ok) {
        // eslint-disable-next-line no-console
        console.error('[resend] send error:', resendResult);
        return res.status(502).json({ error: resendResult.error });
      }

      await Otp.create({ email, codeHash, expiresAt });
      return res.json({ ok: true, provider: 'resend' });
    }

    if (provider !== 'smtp') {
      return res.status(500).json({ error: 'EMAIL_PROVIDER_UNSUPPORTED' });
    }

    const smtpResult = await sendOtpEmailWithSmtp({ email, code, ttlSeconds });
    if (!smtpResult.ok) return res.status(502).json({ error: smtpResult.error });

    await Otp.create({ email, codeHash, expiresAt });
    return res.json({ ok: true, provider: 'smtp' });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[smtp] sendMail error:', err);
    return res.status(500).json({
      error: 'EMAIL_SEND_FAILED',
      message: err?.message || String(err),
    });
  }
});

authRouter.post('/verify-otp', async (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const code = String(req.body?.code || '').trim();

  // eslint-disable-next-line no-console
  console.log('[otp] verify attempt', { email, codeLength: code.length });

  if (!email || !email.includes('@')) return res.status(400).json({ error: 'INVALID_EMAIL' });
  if (!/^\d{6}$/.test(code)) return res.status(400).json({ error: 'INVALID_OTP' });

  const codeHash = sha256(`${email}:${code}`);

  const count = await Otp.countDocuments({ email });
  // eslint-disable-next-line no-console
  console.log('[otp] verify computed', {
    email,
    code,
    codeHashPrefix: codeHash.slice(0, 8),
    existingOtpCount: count,
  });

  const record = await Otp.findOne({ email, codeHash }).sort({ createdAt: -1 });
  if (!record) {
    // eslint-disable-next-line no-console
    console.log('[otp] verify failed: no record');
    return res.status(401).json({ error: 'OTP_INVALID' });
  }
  if (record.expiresAt.getTime() < Date.now()) {
    // eslint-disable-next-line no-console
    console.log('[otp] verify failed: expired');
    return res.status(401).json({ error: 'OTP_EXPIRED' });
  }

  await Otp.deleteMany({ email });

  let user = await User.findOne({ email });
  if (!user) {
    user = await User.create({ email, name: email.split('@')[0] || 'User' });
  }

  const token = signJwt(user);
  return res.json({
    token,
    user: {
      id: String(user._id),
      email: user.email,
      name: user.name,
    },
  });
});

module.exports = { authRouter };

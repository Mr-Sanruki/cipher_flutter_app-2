const express = require('express');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');

const { User } = require('../models/User');
const { Otp } = require('../models/Otp');
const { randomOtp6, sha256 } = require('../lib/crypto');

const authRouter = express.Router();

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

  await Otp.create({ email, codeHash, expiresAt });

  try {
    const provider = String(process.env.EMAIL_PROVIDER || 'smtp').toLowerCase();
    if (provider !== 'smtp') {
      return res.status(500).json({ error: 'EMAIL_PROVIDER_UNSUPPORTED' });
    }

    const host = process.env.SMTP_HOST;
    const port = Number(process.env.SMTP_PORT || 587);
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;
    const from = process.env.SMTP_FROM;
    if (!host) return res.status(500).json({ error: 'SMTP_HOST_MISSING' });
    if (!user) return res.status(500).json({ error: 'SMTP_USER_MISSING' });
    if (!pass) return res.status(500).json({ error: 'SMTP_PASS_MISSING' });
    if (!from) return res.status(500).json({ error: 'SMTP_FROM_MISSING' });

    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
    });

    const info = await transporter.sendMail({
      from,
      to: email,
      subject: 'Your Cipher login code',
      text: `Your Cipher login code is: ${code}. It expires in ${Math.floor(ttlSeconds / 60)} minutes.`,
    });

    // eslint-disable-next-line no-console
    console.log('[smtp] sendMail info:', info?.messageId || info);
    return res.json({ ok: true });
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

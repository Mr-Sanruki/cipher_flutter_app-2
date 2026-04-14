const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { Workspace } = require('../models/Workspace');
const { User } = require('../models/User');

const emailRouter = express.Router();

async function sendViaBrevo({ apiKey, fromEmail, fromName, replyToEmail, replyToName, toEmail, toName, subject, text }) {
  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'api-key': apiKey,
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { email: fromEmail, name: fromName },
      replyTo: replyToEmail ? { email: replyToEmail, name: replyToName || undefined } : undefined,
      to: [{ email: toEmail, name: toName }],
      subject,
      textContent: text,
    }),
  });

  if (!res.ok) {
    let details = '';
    try {
      details = await res.text();
    } catch (_) {}
    const err = new Error(`BREVO_ERROR_${res.status}`);
    err.details = details;
    throw err;
  }

  return res.json().catch(() => ({}));
}

emailRouter.post('/workspaces/:workspaceId/send', requireAuth, async (req, res) => {
  const fromUserId = String(req.user?.sub || '').trim();
  const workspaceId = String(req.params.workspaceId || '').trim();
  const toUserId = String(req.body?.toUserId || '').trim();
  const subject = String(req.body?.subject || '').trim();
  const message = String(req.body?.message || '').trim();

  if (!fromUserId) return res.status(401).json({ error: 'UNAUTHORIZED' });
  if (!workspaceId) return res.status(400).json({ error: 'workspaceId required' });
  if (!toUserId) return res.status(400).json({ error: 'toUserId required' });
  if (!subject) return res.status(400).json({ error: 'subject required' });
  if (!message) return res.status(400).json({ error: 'message required' });

  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'BREVO_API_KEY_MISSING' });

  const configuredSenderEmail = process.env.BREVO_SENDER_EMAIL;
  if (!configuredSenderEmail) return res.status(500).json({ error: 'BREVO_SENDER_EMAIL_MISSING' });

  try {
    const ws = await Workspace.findById(workspaceId).lean();
    if (!ws) return res.status(404).json({ error: 'WORKSPACE_NOT_FOUND' });

    const memberIds = (ws.memberIds || []).map((x) => String(x));
    if (!memberIds.includes(fromUserId)) return res.status(403).json({ error: 'NOT_IN_WORKSPACE' });
    if (!memberIds.includes(toUserId)) return res.status(403).json({ error: 'RECIPIENT_NOT_IN_WORKSPACE' });

    const [fromUser, toUser] = await Promise.all([
      User.findById(fromUserId).lean(),
      User.findById(toUserId).lean(),
    ]);

    if (!fromUser) return res.status(404).json({ error: 'SENDER_NOT_FOUND' });
    if (!toUser) return res.status(404).json({ error: 'RECIPIENT_NOT_FOUND' });
    if (!toUser.email) return res.status(400).json({ error: 'RECIPIENT_EMAIL_MISSING' });
    if (!fromUser.email) return res.status(400).json({ error: 'SENDER_EMAIL_MISSING' });

    const replyToEmail = String(fromUser.email);
    const replyToName = String(fromUser.name || 'User');

    const configuredSenderName = process.env.BREVO_SENDER_NAME;
    const fromEmail = String(configuredSenderEmail);
    const fromName = configuredSenderName ? String(configuredSenderName) : replyToName;

    const text = `From: ${fromUser.name} (${fromUser.email})\nWorkspace: ${ws.name}\n\n${message}`;

    const result = await sendViaBrevo({
      apiKey,
      fromEmail,
      fromName,
      replyToEmail,
      replyToName,
      toEmail: String(toUser.email),
      toName: String(toUser.name || ''),
      subject,
      text,
    });

    return res.json({ ok: true, result });
  } catch (e) {
    if (e && e.details) {
      return res.status(502).json({ error: String(e.message || 'BREVO_ERROR'), details: String(e.details) });
    }
    return res.status(500).json({ error: String(e?.message || e || 'ERROR') });
  }
});

module.exports = { emailRouter };

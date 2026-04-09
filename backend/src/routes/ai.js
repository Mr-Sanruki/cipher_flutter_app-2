const express = require('express');
const { requireAuth } = require('../middleware/auth');

const { decryptText } = require('../lib/message_crypto');

const { Channel } = require('../models/Channel');
const { Group } = require('../models/Group');
const { Dm } = require('../models/Dm');
const { Message } = require('../models/Message');

const aiRouter = express.Router();

async function authorizeChatAccess({ chatType, chatId, userId }) {
  if (chatType === 'dm') {
    const dm = await Dm.findById(chatId).lean();
    if (!dm) return { ok: false, status: 404, error: 'NOT_FOUND' };
    if (!(dm.memberIds || []).some((x) => String(x) === String(userId))) {
      return { ok: false, status: 403, error: 'FORBIDDEN' };
    }
    return { ok: true, workspaceId: dm.workspaceId };
  }

  if (chatType === 'channel') {
    const channel = await Channel.findById(chatId).lean();
    if (!channel) return { ok: false, status: 404, error: 'NOT_FOUND' };
    return { ok: true, workspaceId: channel.workspaceId };
  }

  if (chatType === 'group') {
    const group = await Group.findById(chatId).lean();
    if (!group) return { ok: false, status: 404, error: 'NOT_FOUND' };
    if (!(group.memberIds || []).some((x) => String(x) === String(userId))) {
      return { ok: false, status: 403, error: 'FORBIDDEN' };
    }
    return { ok: true, workspaceId: group.workspaceId };
  }

  return { ok: false, status: 400, error: 'INVALID_CHAT_TYPE' };
}

function safeParseJson(text) {
  if (typeof text !== 'string') return null;
  const trimmed = text.trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch (_) {
    return null;
  }
}

aiRouter.post('/chat', requireAuth, async (req, res) => {
  const raw = req.body;
  const prompt =
    (raw && typeof raw.prompt === 'string' ? raw.prompt : null) ||
    (raw && typeof raw.message === 'string' ? raw.message : null) ||
    (typeof raw === 'string' ? raw : null);

  const messagesRaw =
    (raw && Array.isArray(raw.messages) ? raw.messages : null) ||
    (raw && raw.data && Array.isArray(raw.data.messages) ? raw.data.messages : null) ||
    (raw && Array.isArray(raw.history) ? raw.history : null) ||
    (prompt ? [{ role: 'user', content: prompt }] : []);

  const messages = messagesRaw
    .map((m) => {
      if (!m || typeof m !== 'object') return null;
      const role = String(m.role || '').trim();
      const content = String(m.content || '').trim();
      if (!role || !content) return null;
      return { role, content };
    })
    .filter(Boolean);

  if (messages.length === 0) {
    // eslint-disable-next-line no-console
    console.error('[ai] invalid payload', {
      keys: raw && typeof raw === 'object' ? Object.keys(raw) : typeof raw,
      hasPrompt: Boolean(prompt && String(prompt).trim()),
      messagesType: raw && typeof raw === 'object' ? typeof raw.messages : undefined,
      messagesLength: Array.isArray(raw?.messages) ? raw.messages.length : undefined,
    });
    return res.status(400).json({
      error: 'MESSAGES_REQUIRED',
      hint: 'Expected body: { messages: [{ role: "user"|"assistant", content: "..." }] } or { prompt: "..." }',
    });
  }

  const apiKey = String(process.env.GROQ_API_KEY || process.env.GROK_API_KEY || '').trim();
  if (!apiKey) {
    return res.status(500).json({ error: 'GROQ_API_KEY_MISSING' });
  }

  try {
    const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: String(process.env.GROQ_MODEL || 'llama-3.1-8b-instant'),
        messages: messages,
        max_tokens: 1024,
        temperature: 0.7,
      }),
    });

    if (!groqRes.ok) {
      const text = await groqRes.text().catch(() => '');
      let parsed;
      try {
        parsed = JSON.parse(text);
      } catch (_) {
        parsed = null;
      }
      const message =
        (parsed && parsed.error && typeof parsed.error.message === 'string' && parsed.error.message) ||
        (typeof text === 'string' ? text : '') ||
        'Groq request failed';
      return res.status(groqRes.status).json({
        error: 'GROQ_ERROR',
        message,
        details: text,
      });
    }

    const data = await groqRes.json();
    const content = data?.choices?.[0]?.message?.content || '';
    return res.json({ content });
  } catch (err) {
    console.error('[ai] proxy error:', err);
    return res.status(500).json({ error: 'AI_PROXY_ERROR', message: err.message });
  }
});

aiRouter.post('/summary', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const chatType = String(req.body?.chatType || '').trim();
  const chatId = String(req.body?.chatId || '').trim();
  const limitRaw = Number(req.body?.limit || 80);
  const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 10), 200) : 80;

  if (!userId) return res.status(401).json({ error: 'UNAUTHORIZED' });
  if (!chatType || !chatId) return res.status(400).json({ error: 'CHAT_REQUIRED' });

  const authz = await authorizeChatAccess({ chatType, chatId, userId });
  if (!authz.ok) return res.status(authz.status).json({ error: authz.error });

  const apiKey = String(process.env.GROQ_API_KEY || process.env.GROK_API_KEY || '').trim();
  if (!apiKey) return res.status(500).json({ error: 'GROQ_API_KEY_MISSING' });

  const docs = await Message.find({ chatType, chatId, isDeleted: { $ne: true } })
    .sort({ createdAt: -1 })
    .limit(limit)
    .lean();

  const messagesChrono = docs.slice().reverse().map((m) => {
    const content = m.type === 'text' ? decryptText(m.content) : `[${String(m.type || 'message')}]`;
    const senderName = String(m.senderName || 'User');
    return `${senderName}: ${content}`;
  });

  const system =
    'You are a helpful assistant that summarizes chat conversations. ' +
    'Return STRICT JSON only (no markdown) in this schema: ' +
    '{"summary":"...","actionItems":[{"task":"...","owner":"...","due":"..."}]}. ' +
    'Keep summary concise. Action items can be empty. If owner/due unknown, use empty string.';

  const user =
    `Summarize the following chat messages. WorkspaceId: ${String(authz.workspaceId)}\n\n` +
    messagesChrono.join('\n');

  try {
    const groqRes = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: String(process.env.GROQ_MODEL || 'llama-3.1-8b-instant'),
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
        max_tokens: 1024,
        temperature: 0.3,
      }),
    });

    if (!groqRes.ok) {
      const text = await groqRes.text().catch(() => '');
      const parsed = safeParseJson(text);
      const message =
        (parsed && parsed.error && typeof parsed.error.message === 'string' && parsed.error.message) ||
        (typeof text === 'string' ? text : '') ||
        'Groq request failed';
      return res.status(groqRes.status).json({ error: 'GROQ_ERROR', message, details: text });
    }

    const data = await groqRes.json();
    const content = data?.choices?.[0]?.message?.content || '';
    const json = safeParseJson(String(content || ''));

    if (!json || typeof json.summary !== 'string' || !Array.isArray(json.actionItems)) {
      return res.json({
        summary: String(content || '').trim(),
        actionItems: [],
      });
    }

    return res.json({
      summary: String(json.summary || '').trim(),
      actionItems: (json.actionItems || [])
        .filter((x) => x && typeof x === 'object')
        .map((x) => ({
          task: typeof x.task === 'string' ? x.task : '',
          owner: typeof x.owner === 'string' ? x.owner : '',
          due: typeof x.due === 'string' ? x.due : '',
        })),
    });
  } catch (err) {
    console.error('[ai] summary error:', err);
    return res.status(500).json({ error: 'AI_PROXY_ERROR', message: err.message });
  }
});

module.exports = { aiRouter };

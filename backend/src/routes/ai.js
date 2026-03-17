const express = require('express');
const { requireAuth } = require('../middleware/auth');

const aiRouter = express.Router();

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

module.exports = { aiRouter };

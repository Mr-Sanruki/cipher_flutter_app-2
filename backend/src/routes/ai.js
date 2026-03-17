const express = require('express');
const { requireAuth } = require('../middleware/auth');

const aiRouter = express.Router();

aiRouter.post('/chat', requireAuth, async (req, res) => {
  const raw = req.body;
  const messagesRaw =
    (raw && Array.isArray(raw.messages) ? raw.messages : null) ||
    (raw && raw.data && Array.isArray(raw.data.messages) ? raw.data.messages : null) ||
    (raw && Array.isArray(raw.history) ? raw.history : null) ||
    [];

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
    return res.status(400).json({
      error: 'MESSAGES_REQUIRED',
      hint: 'Expected body: { messages: [{ role: "user"|"assistant", content: "..." }] }',
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
        model: 'llama3-8b-8192',
        messages: messages,
        max_tokens: 1024,
        temperature: 0.7,
      }),
    });

    if (!groqRes.ok) {
      const text = await groqRes.text();
      return res.status(groqRes.status).json({ error: 'GROQ_ERROR', details: text });
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

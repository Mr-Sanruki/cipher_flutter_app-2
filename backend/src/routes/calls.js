const express = require('express');
const { StreamChat } = require('stream-chat');

const { requireAuth } = require('../middleware/auth');

const callsRouter = express.Router();

callsRouter.get('/token', requireAuth, async (req, res) => {
  const userId = String(req.user?.sub || '').trim();
  if (!userId) return res.status(401).json({ error: 'UNAUTHORIZED' });

  const apiKey = String(process.env.STREAM_API_KEY || '').trim();
  const apiSecret = String(process.env.STREAM_API_SECRET || '').trim();

  if (!apiKey) return res.status(500).json({ error: 'STREAM_API_KEY_MISSING' });
  if (!apiSecret) return res.status(500).json({ error: 'STREAM_API_SECRET_MISSING' });

  const serverClient = StreamChat.getInstance(apiKey, apiSecret);
  const token = serverClient.createToken(userId);

  return res.json({ token });
});

module.exports = { callsRouter };

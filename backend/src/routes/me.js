const express = require('express');
const { User } = require('../models/User');
const { requireAuth } = require('../middleware/auth');

const meRouter = express.Router();

function toUserDto(user) {
  return {
    id: String(user._id),
    email: user.email,
    name: user.name,
    avatarUrl: user.avatarUrl,
    bio: user.bio,
    workspaceIds: (user.workspaceIds || []).map((x) => String(x)),
    notificationsEnabled: user.notificationsEnabled !== false,
    isOnline: Boolean(user.isOnline),
    lastSeenAt: user.lastSeenAt,
    createdAt: user.createdAt,
  };
}

meRouter.get('/', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const user = await User.findById(userId).lean();
  if (!user) return res.status(404).json({ error: 'NOT_FOUND' });

  return res.json(toUserDto(user));
});

meRouter.patch('/', requireAuth, async (req, res) => {
  const userId = req.user?.sub;

  const name = req.body?.name != null ? String(req.body.name).trim() : undefined;
  const bio = req.body?.bio != null ? String(req.body.bio).trim() : undefined;
  const avatarUrl = req.body?.avatarUrl != null ? String(req.body.avatarUrl).trim() : undefined;
  const notificationsEnabled =
    req.body?.notificationsEnabled != null ? Boolean(req.body.notificationsEnabled) : undefined;

  if (name != null && name.length === 0) return res.status(400).json({ error: 'INVALID_NAME' });

  const update = {};
  if (name != null) update.name = name;
  if (bio != null) update.bio = bio;
  if (avatarUrl != null) update.avatarUrl = avatarUrl;
  if (notificationsEnabled != null) update.notificationsEnabled = notificationsEnabled;

  const user = await User.findByIdAndUpdate(userId, { $set: update }, { new: true }).lean();
  if (!user) return res.status(404).json({ error: 'NOT_FOUND' });
  return res.json(toUserDto(user));
});

meRouter.post('/presence', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const isOnline = Boolean(req.body?.isOnline);

  const update = {
    isOnline,
    ...(isOnline ? {} : { lastSeenAt: new Date() }),
  };

  await User.updateOne({ _id: userId }, { $set: update });
  return res.json({ ok: true });
});

meRouter.delete('/', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  await User.deleteOne({ _id: userId });
  return res.json({ ok: true });
});

module.exports = { meRouter };

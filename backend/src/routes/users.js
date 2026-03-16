const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { User } = require('../models/User');

const usersRouter = express.Router();

function toUserDto(u) {
  return {
    id: String(u._id),
    email: u.email,
    name: u.name,
    avatarUrl: u.avatarUrl,
    bio: u.bio,
    workspaceIds: (u.workspaceIds || []).map((x) => String(x)),
    notificationsEnabled: u.notificationsEnabled !== false,
    isOnline: Boolean(u.isOnline),
    lastSeenAt: u.lastSeenAt,
    createdAt: u.createdAt,
  };
}

usersRouter.post('/bulk', requireAuth, async (req, res) => {
  const ids = Array.isArray(req.body?.ids) ? req.body.ids.map((x) => String(x)) : [];
  const uniq = Array.from(new Set(ids)).filter((x) => x);
  if (uniq.length === 0) return res.json({ items: [] });

  const users = await User.find({ _id: { $in: uniq } }).lean();
  const byId = new Map(users.map((u) => [String(u._id), u]));
  const items = uniq
    .map((id) => byId.get(String(id)))
    .filter(Boolean)
    .map(toUserDto);

  return res.json({ items });
});

module.exports = { usersRouter };

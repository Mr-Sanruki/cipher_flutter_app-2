const express = require('express');
const crypto = require('crypto');

const { requireAuth } = require('../middleware/auth');
const { Workspace } = require('../models/Workspace');

const workspacesRouter = express.Router();

function randomInviteCode() {
  return crypto.randomBytes(4).toString('hex').toUpperCase();
}

function toDto(ws) {
  const mapToObj = (v) => {
    if (!v) return {};
    if (v instanceof Map) return Object.fromEntries(v);
    if (typeof v === 'object') return v;
    return {};
  };

  return {
    id: String(ws._id),
    name: ws.name,
    description: ws.description,
    iconUrl: ws.iconUrl,
    ownerId: String(ws.ownerId),
    memberIds: (ws.memberIds || []).map((x) => String(x)),
    adminIds: (ws.adminIds || []).map((x) => String(x)),
    memberRoles: mapToObj(ws.memberRoles),
    inviteCode: ws.inviteCode,
    createdAt: ws.createdAt,
  };
}

workspacesRouter.get('/', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const items = await Workspace.find({ memberIds: userId }).sort({ createdAt: -1 }).lean();
  return res.json({ items: items.map(toDto) });
});

workspacesRouter.post('/', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const name = String(req.body?.name || '').trim();
  const description = req.body?.description != null ? String(req.body.description).trim() : undefined;

  if (!name) return res.status(400).json({ error: 'INVALID_NAME' });

  let inviteCode;
  for (let i = 0; i < 5; i += 1) {
    inviteCode = randomInviteCode();
    // eslint-disable-next-line no-await-in-loop
    const exists = await Workspace.findOne({ inviteCode }).lean();
    if (!exists) break;
  }
  if (!inviteCode) return res.status(500).json({ error: 'INVITE_CODE_GEN_FAILED' });

  const ws = await Workspace.create({
    name,
    description,
    ownerId: userId,
    memberIds: [userId],
    adminIds: [userId],
    memberRoles: { [userId]: 'owner' },
    inviteCode,
  });

  return res.status(201).json({ workspace: toDto(ws.toObject ? ws.toObject() : ws) });
});

workspacesRouter.post('/join', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const code = String(req.body?.code || '').trim().toUpperCase();

  if (!code) return res.status(400).json({ error: 'INVALID_CODE' });

  const ws = await Workspace.findOne({ inviteCode: code });
  if (!ws) return res.status(404).json({ error: 'NOT_FOUND' });

  const isMember = (ws.memberIds || []).some((x) => String(x) === String(userId));
  if (!isMember) {
    ws.memberIds = [...(ws.memberIds || []), userId];
    if (!ws.memberRoles) ws.memberRoles = new Map();
    if (ws.memberRoles.get(String(userId)) == null) ws.memberRoles.set(String(userId), 'member');
    await ws.save();
  }

  return res.json({ workspace: toDto(ws.toObject()) });
});

workspacesRouter.post('/:id/leave', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const id = String(req.params.id || '').trim();

  const ws = await Workspace.findById(id);
  if (!ws) return res.status(404).json({ error: 'NOT_FOUND' });

  ws.memberIds = (ws.memberIds || []).filter((x) => String(x) !== String(userId));
  ws.adminIds = (ws.adminIds || []).filter((x) => String(x) !== String(userId));
  if (ws.memberRoles) ws.memberRoles.delete(String(userId));

  if (String(ws.ownerId) === String(userId)) {
    if ((ws.memberIds || []).length === 0) {
      await ws.deleteOne();
      return res.json({ ok: true, deleted: true });
    }
    ws.ownerId = ws.memberIds[0];
    if (!ws.adminIds.some((x) => String(x) === String(ws.ownerId))) {
      ws.adminIds.push(ws.ownerId);
    }
    if (!ws.memberRoles) ws.memberRoles = new Map();
    ws.memberRoles.set(String(ws.ownerId), 'owner');
  }

  await ws.save();
  return res.json({ ok: true });
});

workspacesRouter.put('/:id', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const id = String(req.params.id || '').trim();

  const ws = await Workspace.findById(id);
  if (!ws) return res.status(404).json({ error: 'NOT_FOUND' });

  if (String(ws.ownerId) !== String(userId)) {
    return res.status(403).json({ error: 'FORBIDDEN' });
  }

  const name = req.body?.name != null ? String(req.body.name).trim() : undefined;
  const description = req.body?.description != null ? String(req.body.description).trim() : undefined;
  const iconUrl = req.body?.iconUrl != null ? String(req.body.iconUrl).trim() : undefined;

  if (name != null && name.length === 0) return res.status(400).json({ error: 'INVALID_NAME' });

  if (name != null) ws.name = name;
  if (description != null) ws.description = description;
  if (iconUrl != null) ws.iconUrl = iconUrl;

  await ws.save();
  return res.json({ workspace: toDto(ws.toObject()) });
});

workspacesRouter.post('/:id/roles', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const id = String(req.params.id || '').trim();
  const memberId = String(req.body?.memberId || '').trim();
  const role = String(req.body?.role || '').trim();

  if (!memberId) return res.status(400).json({ error: 'MEMBER_ID_REQUIRED' });
  if (!['member', 'admin'].includes(role)) return res.status(400).json({ error: 'INVALID_ROLE' });

  const ws = await Workspace.findById(id);
  if (!ws) return res.status(404).json({ error: 'NOT_FOUND' });

  const isOwner = String(ws.ownerId) === String(userId);
  const isAdmin = (ws.adminIds || []).some((x) => String(x) === String(userId));
  if (!isOwner && !isAdmin) return res.status(403).json({ error: 'FORBIDDEN' });

  if (!(ws.memberIds || []).some((x) => String(x) === String(memberId))) {
    return res.status(404).json({ error: 'MEMBER_NOT_FOUND' });
  }
  if (String(ws.ownerId) === String(memberId)) {
    return res.status(400).json({ error: 'CANNOT_CHANGE_OWNER_ROLE' });
  }

  if (!ws.memberRoles) ws.memberRoles = new Map();
  ws.memberRoles.set(String(memberId), role);

  if (role === 'admin') {
    if (!(ws.adminIds || []).some((x) => String(x) === String(memberId))) {
      ws.adminIds = [...(ws.adminIds || []), memberId];
    }
  } else {
    ws.adminIds = (ws.adminIds || []).filter((x) => String(x) !== String(memberId));
  }

  await ws.save();
  return res.json({ workspace: toDto(ws.toObject()) });
});

module.exports = { workspacesRouter };

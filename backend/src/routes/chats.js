const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { Workspace } = require('../models/Workspace');
const { Channel } = require('../models/Channel');
const { Group } = require('../models/Group');
const { Dm } = require('../models/Dm');
const { Message } = require('../models/Message');

function toChannelDto(c) {
  return {
    id: String(c._id),
    workspaceId: String(c.workspaceId),
    name: c.name,
    description: c.description,
    createdBy: String(c.createdBy),
    isAnnouncement: Boolean(c.isAnnouncement),
    createdAt: c.createdAt,
  };
}

function toGroupDto(g) {
  return {
    id: String(g._id),
    workspaceId: String(g.workspaceId),
    name: g.name,
    iconUrl: g.iconUrl,
    createdBy: String(g.createdBy),
    memberIds: (g.memberIds || []).map((x) => String(x)),
    createdAt: g.createdAt,
  };
}

function toDmDto(d) {
  return {
    id: String(d._id),
    workspaceId: String(d.workspaceId),
    memberIds: (d.memberIds || []).map((x) => String(x)),
    lastMessage: d.lastMessage,
    lastMessageAt: d.lastMessageAt,
    createdAt: d.createdAt,
  };
}

function toMessageDto(m) {
  const mapToObj = (v) => {
    if (!v) return {};
    if (v instanceof Map) return Object.fromEntries(v);
    if (typeof v === 'object') return v;
    return {};
  };

  return {
    id: String(m._id),
    workspaceId: String(m.workspaceId),
    chatType: m.chatType,
    chatId: String(m.chatId),
    senderId: String(m.senderId),
    senderName: m.senderName,
    senderAvatar: m.senderAvatar,
    content: m.content,
    type: m.type,
    fileUrl: m.fileUrl,
    fileName: m.fileName,
    fileSize: m.fileSize,
    isEdited: Boolean(m.isEdited),
    isDeleted: Boolean(m.isDeleted),
    threadCount: Number(m.threadCount || 0),
    parentMessageId: m.parentMessageId ? String(m.parentMessageId) : null,
    deliveredTo: mapToObj(m.deliveredTo),
    readBy: mapToObj(m.readBy),
    reactions: mapToObj(m.reactions),
    forwardOf: m.forwardOf
      ? {
          messageId: m.forwardOf.messageId ? String(m.forwardOf.messageId) : null,
          chatType: m.forwardOf.chatType,
          chatId: m.forwardOf.chatId ? String(m.forwardOf.chatId) : null,
          senderId: m.forwardOf.senderId ? String(m.forwardOf.senderId) : null,
          content: m.forwardOf.content,
          type: m.forwardOf.type,
          fileUrl: m.forwardOf.fileUrl,
          fileName: m.forwardOf.fileName,
          fileSize: m.forwardOf.fileSize,
          createdAt: m.forwardOf.createdAt,
        }
      : null,
    createdAt: m.createdAt,
    editedAt: m.editedAt,
  };
}

function roomFor(chatType, chatId) {
  return `chat:${chatType}:${String(chatId)}`;
}

function createChatsRouter(io) {
  const router = express.Router();

  async function authorizeChatAccess({ chatType, chatId, userId }) {
    if (chatType === 'dm') {
      const dm = await Dm.findById(chatId).lean();
      if (!dm) return { ok: false, status: 404, error: 'NOT_FOUND' };
      if (!(dm.memberIds || []).some((x) => String(x) === String(userId))) {
        return { ok: false, status: 403, error: 'FORBIDDEN' };
      }
      return { ok: true, workspaceId: dm.workspaceId };
    }
    if (chatType === 'group') {
      const g = await Group.findById(chatId).lean();
      if (!g) return { ok: false, status: 404, error: 'NOT_FOUND' };
      if (!(g.memberIds || []).some((x) => String(x) === String(userId))) {
        return { ok: false, status: 403, error: 'FORBIDDEN' };
      }
      return { ok: true, workspaceId: g.workspaceId };
    }
    if (chatType === 'channel') {
      const c = await Channel.findById(chatId).lean();
      if (!c) return { ok: false, status: 404, error: 'NOT_FOUND' };
      const ws = await Workspace.findById(c.workspaceId).lean();
      if (!ws) return { ok: false, status: 404, error: 'WORKSPACE_NOT_FOUND' };
      if (!(ws.memberIds || []).some((x) => String(x) === String(userId))) {
        return { ok: false, status: 403, error: 'FORBIDDEN' };
      }
      return { ok: true, workspaceId: c.workspaceId };
    }
    return { ok: false, status: 400, error: 'INVALID_CHAT_TYPE' };
  }

  async function createMessage(req, res, { parentMessageIdOverride } = {}) {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();

    const content = String(req.body?.content || '').trim();
    const senderName = String(req.body?.senderName || '').trim();
    const senderAvatar = req.body?.senderAvatar != null ? String(req.body.senderAvatar).trim() : undefined;
    const type = String(req.body?.type || 'text').trim();
    const fileUrl = req.body?.fileUrl != null ? String(req.body.fileUrl).trim() : undefined;
    const fileName = req.body?.fileName != null ? String(req.body.fileName).trim() : undefined;
    const fileSize = req.body?.fileSize != null ? String(req.body.fileSize).trim() : undefined;

    const parentMessageIdRaw =
      parentMessageIdOverride != null
        ? String(parentMessageIdOverride).trim()
        : req.body?.parentMessageId != null
            ? String(req.body.parentMessageId).trim()
            : undefined;

    if (!['channel', 'dm', 'group'].includes(chatType)) {
      return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });
    }
    if (!content) return res.status(400).json({ error: 'EMPTY_MESSAGE' });
    if (!senderName) return res.status(400).json({ error: 'SENDER_NAME_REQUIRED' });

    const authz = await authorizeChatAccess({ chatType, chatId, userId });
    if (!authz.ok) return res.status(authz.status).json({ error: authz.error });
    const workspaceId = authz.workspaceId;

    if (chatType === 'dm') {
      await Dm.updateOne({ _id: chatId }, { $set: { lastMessage: content, lastMessageAt: new Date() } });
    }

    const now = new Date();
    const msg = await Message.create({
      workspaceId,
      chatType,
      chatId,
      senderId: userId,
      senderName,
      senderAvatar,
      content,
      type,
      fileUrl,
      fileName,
      fileSize,
      isDeleted: false,
      deliveredTo: { [String(userId)]: now },
      readBy: { [String(userId)]: now },
      parentMessageId: parentMessageIdRaw,
      createdAt: now,
    });

    if (parentMessageIdRaw) {
      await Message.updateOne({ _id: parentMessageIdRaw }, { $inc: { threadCount: 1 } });
    }

    const dto = toMessageDto(msg.toObject());
    if (io) {
      io.to(roomFor(chatType, chatId)).emit('message:new', dto);
    }

    return res.status(201).json({ message: dto });
  }

  // Channels
  router.get('/channels', requireAuth, async (req, res) => {
    const workspaceId = String(req.query.workspaceId || '').trim();
    if (!workspaceId) return res.status(400).json({ error: 'WORKSPACE_ID_REQUIRED' });

    const items = await Channel.find({ workspaceId }).sort({ createdAt: 1 }).lean();
    return res.json({ items: items.map(toChannelDto) });
  });

  router.post('/channels', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const workspaceId = String(req.body?.workspaceId || '').trim();
    const name = String(req.body?.name || '').trim();
    const description = req.body?.description != null ? String(req.body.description).trim() : undefined;
    const isAnnouncement = Boolean(req.body?.isAnnouncement);

    if (!workspaceId) return res.status(400).json({ error: 'WORKSPACE_ID_REQUIRED' });
    if (!name) return res.status(400).json({ error: 'INVALID_NAME' });

    const ws = await Workspace.findById(workspaceId).lean();
    if (!ws) return res.status(404).json({ error: 'WORKSPACE_NOT_FOUND' });
    if (!(ws.memberIds || []).some((x) => String(x) === String(userId))) {
      return res.status(403).json({ error: 'FORBIDDEN' });
    }

    try {
      const c = await Channel.create({ workspaceId, name, description, createdBy: userId, isAnnouncement });
      return res.status(201).json({ channel: toChannelDto(c.toObject()) });
    } catch (e) {
      if (String(e?.code) === '11000') return res.status(409).json({ error: 'CHANNEL_EXISTS' });
      return res.status(500).json({ error: 'INTERNAL_ERROR' });
    }
  });

  // Groups
  router.get('/groups', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const workspaceId = String(req.query.workspaceId || '').trim();
    if (!workspaceId) return res.status(400).json({ error: 'WORKSPACE_ID_REQUIRED' });

    const items = await Group.find({ workspaceId, memberIds: userId }).sort({ createdAt: 1 }).lean();
    return res.json({ items: items.map(toGroupDto) });
  });

  router.post('/groups', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const workspaceId = String(req.body?.workspaceId || '').trim();
    const name = String(req.body?.name || '').trim();
    const memberIds = Array.isArray(req.body?.memberIds) ? req.body.memberIds.map(String) : [];

    if (!workspaceId) return res.status(400).json({ error: 'WORKSPACE_ID_REQUIRED' });
    if (!name) return res.status(400).json({ error: 'INVALID_NAME' });

    const ws = await Workspace.findById(workspaceId).lean();
    if (!ws) return res.status(404).json({ error: 'WORKSPACE_NOT_FOUND' });
    if (!(ws.memberIds || []).some((x) => String(x) === String(userId))) {
      return res.status(403).json({ error: 'FORBIDDEN' });
    }

    const unique = [...new Set([userId, ...memberIds])];
    const g = await Group.create({ workspaceId, name, createdBy: userId, memberIds: unique });
    return res.status(201).json({ group: toGroupDto(g.toObject()) });
  });

  // DMs
  router.get('/dms', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const workspaceId = String(req.query.workspaceId || '').trim();
    if (!workspaceId) return res.status(400).json({ error: 'WORKSPACE_ID_REQUIRED' });

    const items = await Dm.find({ workspaceId, memberIds: userId }).sort({ lastMessageAt: -1, createdAt: -1 }).lean();
    return res.json({ items: items.map(toDmDto) });
  });

  router.post('/dms', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const workspaceId = String(req.body?.workspaceId || '').trim();
    const otherUserId = String(req.body?.otherUserId || '').trim();

    if (!workspaceId) return res.status(400).json({ error: 'WORKSPACE_ID_REQUIRED' });
    if (!otherUserId) return res.status(400).json({ error: 'OTHER_USER_REQUIRED' });

    const ids = [String(userId), String(otherUserId)].sort();
    const memberKey = ids.join('_');

    let dm = await Dm.findOne({ workspaceId, memberKey });
    if (!dm) {
      dm = await Dm.create({ workspaceId, memberIds: ids, memberKey });
    }

    return res.json({ dm: toDmDto(dm.toObject()) });
  });

  // Messages
  router.get('/:chatType/:chatId/messages', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();
    const limit = Math.min(Number(req.query.limit || 50), 100);

    if (!['channel', 'dm', 'group'].includes(chatType)) {
      return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });
    }

    const authz = await authorizeChatAccess({ chatType, chatId, userId });
    if (!authz.ok) return res.status(authz.status).json({ error: authz.error });

    const items = await Message.find({ chatType, chatId }).sort({ createdAt: -1 }).limit(limit).lean();
    return res.json({ items: items.map(toMessageDto) });
  });

  router.get('/:chatType/:chatId/messages/search', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();
    const q = String(req.query.q || '').trim();
    const limit = Math.min(Number(req.query.limit || 30), 50);

    if (!q) return res.status(400).json({ error: 'QUERY_REQUIRED' });
    if (!['channel', 'dm', 'group'].includes(chatType)) return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });

    const authz = await authorizeChatAccess({ chatType, chatId, userId });
    if (!authz.ok) return res.status(authz.status).json({ error: authz.error });

    const items = await Message.find(
      { chatType, chatId, isDeleted: false, $text: { $search: q } },
      { score: { $meta: 'textScore' } }
    )
      .sort({ score: { $meta: 'textScore' }, createdAt: -1 })
      .limit(limit)
      .lean();

    return res.json({ items: items.map(toMessageDto) });
  });

  router.post('/:chatType/:chatId/messages', requireAuth, async (req, res) => createMessage(req, res));

  router.get('/:chatType/:chatId/messages/:messageId/threads', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();
    const messageId = String(req.params.messageId || '').trim();

    if (!['channel', 'dm', 'group'].includes(chatType)) {
      return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });
    }

    const authz = await authorizeChatAccess({ chatType, chatId, userId });
    if (!authz.ok) return res.status(authz.status).json({ error: authz.error });

    const items = await Message.find({ chatType, chatId, parentMessageId: messageId })
      .sort({ createdAt: 1 })
      .lean();
    return res.json({ items: items.map(toMessageDto) });
  });

  router.post('/:chatType/:chatId/messages/:messageId/reactions', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();
    const messageId = String(req.params.messageId || '').trim();
    const emoji = String(req.body?.emoji || '').trim();
    const action = String(req.body?.action || 'toggle').trim();

    if (!['channel', 'dm', 'group'].includes(chatType)) return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });
    if (!emoji) return res.status(400).json({ error: 'EMOJI_REQUIRED' });
    if (emoji.length > 32) return res.status(400).json({ error: 'EMOJI_TOO_LONG' });
    if (!['add', 'remove', 'toggle'].includes(action)) return res.status(400).json({ error: 'INVALID_ACTION' });

    const authz = await authorizeChatAccess({ chatType, chatId, userId });
    if (!authz.ok) return res.status(authz.status).json({ error: authz.error });

    const msg = await Message.findOne({ _id: messageId, chatType, chatId });
    if (!msg) return res.status(404).json({ error: 'NOT_FOUND' });

    const key = `reactions.${emoji}`;
    const current = msg.reactions?.get(emoji) || [];
    const has = current.some((x) => String(x) === String(userId));

    let update;
    if (action === 'add' || (action === 'toggle' && !has)) {
      update = { $addToSet: { [key]: String(userId) } };
    } else {
      update = { $pull: { [key]: String(userId) } };
    }

    const updated = await Message.findOneAndUpdate({ _id: messageId }, update, { new: true }).lean();
    const dto = toMessageDto(updated);
    if (io) io.to(roomFor(chatType, chatId)).emit('message:update', dto);
    return res.json({ message: dto });
  });

  router.post('/:chatType/:chatId/messages/:messageId/forward', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();
    const messageId = String(req.params.messageId || '').trim();

    const targetChatType = String(req.body?.targetChatType || '').trim();
    const targetChatId = String(req.body?.targetChatId || '').trim();
    const senderName = String(req.body?.senderName || '').trim();
    const senderAvatar = req.body?.senderAvatar != null ? String(req.body.senderAvatar).trim() : undefined;

    if (!['channel', 'dm', 'group'].includes(chatType)) return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });
    if (!['channel', 'dm', 'group'].includes(targetChatType)) return res.status(400).json({ error: 'INVALID_TARGET_CHAT_TYPE' });
    if (!targetChatId) return res.status(400).json({ error: 'TARGET_CHAT_ID_REQUIRED' });
    if (!senderName) return res.status(400).json({ error: 'SENDER_NAME_REQUIRED' });

    const authzSource = await authorizeChatAccess({ chatType, chatId, userId });
    if (!authzSource.ok) return res.status(authzSource.status).json({ error: authzSource.error });

    const authzTarget = await authorizeChatAccess({ chatType: targetChatType, chatId: targetChatId, userId });
    if (!authzTarget.ok) return res.status(authzTarget.status).json({ error: authzTarget.error });

    const original = await Message.findOne({ _id: messageId, chatType, chatId }).lean();
    if (!original) return res.status(404).json({ error: 'NOT_FOUND' });

    const now = new Date();
    const msg = await Message.create({
      workspaceId: authzTarget.workspaceId,
      chatType: targetChatType,
      chatId: targetChatId,
      senderId: userId,
      senderName,
      senderAvatar,
      content: original.content,
      type: original.type,
      fileUrl: original.fileUrl,
      fileName: original.fileName,
      fileSize: original.fileSize,
      isDeleted: false,
      deliveredTo: { [String(userId)]: now },
      readBy: { [String(userId)]: now },
      forwardOf: {
        messageId: original._id,
        chatType: original.chatType,
        chatId: original.chatId,
        senderId: original.senderId,
        content: original.content,
        type: original.type,
        fileUrl: original.fileUrl,
        fileName: original.fileName,
        fileSize: original.fileSize,
        createdAt: original.createdAt,
      },
      createdAt: now,
    });

    if (targetChatType === 'dm') {
      await Dm.updateOne({ _id: targetChatId }, { $set: { lastMessage: msg.content, lastMessageAt: now } });
    }

    const dto = toMessageDto(msg.toObject());
    if (io) io.to(roomFor(targetChatType, targetChatId)).emit('message:new', dto);
    return res.status(201).json({ message: dto });
  });

  router.post('/:chatType/:chatId/messages/:messageId/threads', requireAuth, async (req, res) => {
    const messageId = String(req.params.messageId || '').trim();
    return createMessage(req, res, { parentMessageIdOverride: messageId });
  });

  router.post('/:chatType/:chatId/messages/delivered', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();
    const messageIds = Array.isArray(req.body?.messageIds) ? req.body.messageIds.map(String) : [];

    if (!['channel', 'dm', 'group'].includes(chatType)) return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });
    if (messageIds.length === 0) return res.json({ ok: true });

    const now = new Date();
    await Message.updateMany(
      { chatType, chatId, _id: { $in: messageIds } },
      { $set: { [`deliveredTo.${String(userId)}`]: now } }
    );

    return res.json({ ok: true });
  });

  router.post('/:chatType/:chatId/messages/read', requireAuth, async (req, res) => {
    const userId = req.user?.sub;
    const chatType = String(req.params.chatType || '').trim();
    const chatId = String(req.params.chatId || '').trim();
    const messageIds = Array.isArray(req.body?.messageIds) ? req.body.messageIds.map(String) : [];

    if (!['channel', 'dm', 'group'].includes(chatType)) return res.status(400).json({ error: 'INVALID_CHAT_TYPE' });
    if (messageIds.length === 0) return res.json({ ok: true });

    const now = new Date();
    await Message.updateMany(
      { chatType, chatId, _id: { $in: messageIds } },
      { $set: { [`readBy.${String(userId)}`]: now } }
    );

    return res.json({ ok: true });
  });

  return router;
}

module.exports = { createChatsRouter, roomFor };

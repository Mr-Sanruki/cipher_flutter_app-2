const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { DeviceToken } = require('../models/DeviceToken');

const notificationsRouter = express.Router();

notificationsRouter.post('/token', requireAuth, async (req, res) => {
  const userId = req.user?.sub;
  const token = String(req.body?.token || '').trim();
  const platform = req.body?.platform != null ? String(req.body.platform).trim() : 'unknown';
  const deviceId = req.body?.deviceId != null ? String(req.body.deviceId).trim() : undefined;

  if (!token) return res.status(400).json({ error: 'TOKEN_REQUIRED' });

  const now = new Date();

  // Upsert in a way that supports:
  // - token rotation
  // - one token per device
  // - token unique globally
  // If deviceId is provided, we prefer the (userId, deviceId) key.
  try {
    if (deviceId) {
      const doc = await DeviceToken.findOneAndUpdate(
        { userId, deviceId },
        {
          $set: {
            token,
            platform,
            lastSeenAt: now,
            updatedAt: now,
          },
          $setOnInsert: { createdAt: now },
        },
        { upsert: true, new: true }
      );
      return res.json({ ok: true, id: String(doc._id) });
    }

    const doc = await DeviceToken.findOneAndUpdate(
      { token },
      {
        $set: {
          userId,
          platform,
          lastSeenAt: now,
          updatedAt: now,
        },
        $setOnInsert: { createdAt: now },
      },
      { upsert: true, new: true }
    );

    return res.json({ ok: true, id: String(doc._id) });
  } catch (e) {
    // Token is globally unique. If it already exists for another user, re-assign it.
    if (String(e?.code) === '11000') {
      await DeviceToken.updateOne(
        { token },
        { $set: { userId, platform, lastSeenAt: now, updatedAt: now } }
      );
      return res.json({ ok: true });
    }

    return res.status(500).json({ error: 'INTERNAL_ERROR' });
  }
});

module.exports = { notificationsRouter };

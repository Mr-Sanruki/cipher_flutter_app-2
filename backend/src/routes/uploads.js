const express = require('express');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');

const { requireAuth } = require('../middleware/auth');

const uploadsRouter = express.Router();

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads');

function ensureDir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function randomName(originalName) {
  const ext = path.extname(String(originalName || '')).slice(0, 10);
  return `${Date.now()}_${crypto.randomBytes(8).toString('hex')}${ext}`;
}

function publicUrl(req, filePathAbs) {
  const rel = path
    .relative(UPLOAD_ROOT, filePathAbs)
    .split(path.sep)
    .join('/');
  const base = `${req.protocol}://${req.get('host')}`;
  return `${base}/static/${rel}`;
}

function diskStorage(subdir) {
  return multer.diskStorage({
    destination: (_req, _file, cb) => {
      const dir = path.join(UPLOAD_ROOT, subdir);
      ensureDir(dir);
      cb(null, dir);
    },
    filename: (_req, file, cb) => {
      cb(null, randomName(file.originalname));
    },
  });
}

const uploadAvatar = multer({
  storage: diskStorage('avatars'),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const uploadChatFile = multer({
  storage: diskStorage('chat-files'),
  limits: { fileSize: 50 * 1024 * 1024 },
});

const uploadChatImage = multer({
  storage: diskStorage('chat-images'),
  limits: { fileSize: 15 * 1024 * 1024 },
});

uploadsRouter.post('/avatar', requireAuth, uploadAvatar.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'FILE_REQUIRED' });
  return res.json({ url: publicUrl(req, req.file.path) });
});

uploadsRouter.post('/chat-file', requireAuth, uploadChatFile.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'FILE_REQUIRED' });
  const chatId = req.body?.chatId != null ? String(req.body.chatId) : undefined;
  return res.json({ url: publicUrl(req, req.file.path), chatId });
});

uploadsRouter.post('/chat-image', requireAuth, uploadChatImage.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'FILE_REQUIRED' });
  const chatId = req.body?.chatId != null ? String(req.body.chatId) : undefined;
  return res.json({ url: publicUrl(req, req.file.path), chatId });
});

module.exports = { uploadsRouter, UPLOAD_ROOT };

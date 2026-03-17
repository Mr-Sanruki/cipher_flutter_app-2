const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { Server } = require('socket.io');
require('dotenv').config();

const { connectDb } = require('./lib/db');
const { authRouter } = require('./routes/auth');
const { meRouter } = require('./routes/me');
const { usersRouter } = require('./routes/users');
const { workspacesRouter } = require('./routes/workspaces');
const { notificationsRouter } = require('./routes/notifications');
const { uploadsRouter, UPLOAD_ROOT } = require('./routes/uploads');
const { createChatsRouter, roomFor } = require('./routes/chats');
const { callsRouter } = require('./routes/calls');
const { aiRouter } = require('./routes/ai');
const { verifyJwtToken } = require('./middleware/auth');

async function start() {
  await connectDb();

  const app = express();

  app.use(helmet());
  app.use(cors({ origin: true, credentials: true }));
  app.use(express.json({ limit: '1mb' }));

  app.set('trust proxy', 1);

  app.use(
    rateLimit({
      windowMs: 60 * 1000,
      limit: 120,
      standardHeaders: true,
      legacyHeaders: false,
    })
  );

  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  app.use('/auth', authRouter);
  app.use('/me', meRouter);
  app.use('/users', usersRouter);
  app.use('/workspaces', workspacesRouter);
  app.use('/notifications', notificationsRouter);
  app.use('/uploads', uploadsRouter);
  app.use('/static', express.static(UPLOAD_ROOT));
  app.use('/calls', callsRouter);
  app.use('/ai', aiRouter);

  const server = http.createServer(app);

  const io = new Server(server, {
    cors: { origin: true, credentials: true },
  });

  io.use((socket, next) => {
    const authHeader = socket.handshake.headers?.authorization;
    const raw =
      socket.handshake.auth?.token ||
      (typeof authHeader === 'string' ? authHeader.split(' ')[1] : null) ||
      socket.handshake.query?.token;

    const v = verifyJwtToken(raw);
    if (!v.ok) return next(new Error(v.error || 'UNAUTHORIZED'));
    socket.user = v.payload;
    return next();
  });

  io.on('connection', (socket) => {
    socket.on('chat:join', ({ chatType, chatId }) => {
      if (!chatType || !chatId) return;
      socket.join(roomFor(String(chatType), String(chatId)));
    });

    socket.on('chat:leave', ({ chatType, chatId }) => {
      if (!chatType || !chatId) return;
      socket.leave(roomFor(String(chatType), String(chatId)));
    });

    socket.on('typing', ({ chatType, chatId, isTyping }) => {
      if (!chatType || !chatId) return;
      socket.to(roomFor(String(chatType), String(chatId))).emit('typing', {
        chatType: String(chatType),
        chatId: String(chatId),
        userId: String(socket.user?.sub || ''),
        isTyping: Boolean(isTyping),
      });
    });
  });

  app.use('/chats', createChatsRouter(io));

  const port = Number(process.env.PORT || 8080);
  server.listen(port, '0.0.0.0', () => {
    // eslint-disable-next-line no-console
    console.log(`Backend listening on http://0.0.0.0:${port} (LAN) and http://localhost:${port}`);
  });
}

start().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});

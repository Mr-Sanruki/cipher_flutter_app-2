const jwt = require('jsonwebtoken');

function verifyJwtFromRequest(req) {
  const header = req.headers.authorization || '';
  const [, token] = header.split(' ');
  if (!token) return { ok: false, error: 'UNAUTHORIZED' };

  const secret = process.env.JWT_SECRET;
  if (!secret) return { ok: false, error: 'JWT_SECRET_MISSING', status: 500 };

  try {
    const payload = jwt.verify(token, secret);
    return { ok: true, payload };
  } catch (_) {
    return { ok: false, error: 'UNAUTHORIZED' };
  }
}

function verifyJwtToken(token) {
  if (!token) return { ok: false, error: 'UNAUTHORIZED' };
  const secret = process.env.JWT_SECRET;
  if (!secret) return { ok: false, error: 'JWT_SECRET_MISSING', status: 500 };

  try {
    const payload = jwt.verify(token, secret);
    return { ok: true, payload };
  } catch (_) {
    return { ok: false, error: 'UNAUTHORIZED' };
  }
}

function requireAuth(req, res, next) {
  const v = verifyJwtFromRequest(req);
  if (!v.ok) return res.status(v.status || 401).json({ error: v.error });
  req.user = v.payload;
  return next();
}

module.exports = { requireAuth, verifyJwtFromRequest, verifyJwtToken };

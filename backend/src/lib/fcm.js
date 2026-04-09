const admin = require('firebase-admin');

let _initialized = false;
let _messaging = null;

function getMessaging() {
  if (_initialized) return _messaging;
  _initialized = true;

  const raw = String(process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '').trim();
  if (!raw) return null;

  try {
    const jsonStr = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
    const serviceAccount = JSON.parse(jsonStr);

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    _messaging = admin.messaging();
    return _messaging;
  } catch (_e) {
    return null;
  }
}

async function sendMulticast({ tokens, notification, data }) {
  const messaging = getMessaging();
  if (!messaging) return { ok: false, error: 'FCM_NOT_CONFIGURED' };

  const safeTokens = Array.isArray(tokens) ? tokens.filter((t) => typeof t === 'string' && t.trim().length > 0) : [];
  if (safeTokens.length === 0) return { ok: true, sent: 0 };

  const chunks = [];
  for (let i = 0; i < safeTokens.length; i += 500) chunks.push(safeTokens.slice(i, i + 500));

  let sent = 0;
  for (const chunk of chunks) {
    // sendEachForMulticast exists in firebase-admin v11+
    const res = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification,
      data,
    });
    sent += Number(res?.successCount || 0);
  }

  return { ok: true, sent };
}

module.exports = { getMessaging, sendMulticast };

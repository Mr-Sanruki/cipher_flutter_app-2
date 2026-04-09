const crypto = require('crypto');

function getKey() {
  const raw = String(process.env.MESSAGE_ENCRYPTION_KEY || '').trim();
  if (!raw) return null;

  // Support: 64-char hex, base64, or plain text.
  if (/^[0-9a-fA-F]{64}$/.test(raw)) return Buffer.from(raw, 'hex');
  try {
    const b = Buffer.from(raw, 'base64');
    if (b.length === 32) return b;
  } catch (_) {}

  // Derive 32 bytes from any string.
  return crypto.createHash('sha256').update(raw).digest();
}

function encryptText(plainText) {
  const key = getKey();
  if (!key) return String(plainText ?? '');

  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(String(plainText ?? ''), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();

  // enc:v1:<iv_b64>:<tag_b64>:<cipher_b64>
  return `enc:v1:${iv.toString('base64')}:${tag.toString('base64')}:${enc.toString('base64')}`;
}

function decryptText(storedValue) {
  const raw = String(storedValue ?? '');
  if (!raw.startsWith('enc:v1:')) return raw;

  const key = getKey();
  if (!key) return raw;

  const parts = raw.split(':');
  if (parts.length !== 5) return raw;

  try {
    const iv = Buffer.from(parts[2], 'base64');
    const tag = Buffer.from(parts[3], 'base64');
    const data = Buffer.from(parts[4], 'base64');
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    const dec = Buffer.concat([decipher.update(data), decipher.final()]);
    return dec.toString('utf8');
  } catch (_) {
    return raw;
  }
}

module.exports = { encryptText, decryptText };

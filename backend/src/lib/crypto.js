const crypto = require('crypto');

function randomOtp6() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function sha256(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

module.exports = { randomOtp6, sha256 };

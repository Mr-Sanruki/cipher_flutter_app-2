const mongoose = require('mongoose');

const deviceTokenSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    token: { type: String, required: true, index: true, unique: true },
    platform: { type: String, default: 'unknown' },
    deviceId: { type: String },
    lastSeenAt: { type: Date },
    createdAt: { type: Date, default: () => new Date() },
    updatedAt: { type: Date, default: () => new Date() },
  },
  { versionKey: false }
);

deviceTokenSchema.index({ userId: 1, deviceId: 1 }, { unique: true, sparse: true });

deviceTokenSchema.pre('save', function preSave(next) {
  this.updatedAt = new Date();
  next();
});

const DeviceToken = mongoose.model('DeviceToken', deviceTokenSchema);

module.exports = { DeviceToken };

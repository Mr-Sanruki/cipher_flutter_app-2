const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    name: { type: String, required: true },
    avatarUrl: { type: String },
    bio: { type: String },
    workspaceIds: { type: [mongoose.Schema.Types.ObjectId], default: [] },
    notificationsEnabled: { type: Boolean, default: true },
    isOnline: { type: Boolean, default: false },
    createdAt: { type: Date, default: () => new Date() },
    lastSeenAt: { type: Date },
  },
  { versionKey: false }
);

const User = mongoose.model('User', userSchema);

module.exports = { User };

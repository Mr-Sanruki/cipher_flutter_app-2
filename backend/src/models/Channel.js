const mongoose = require('mongoose');

const channelSchema = new mongoose.Schema(
  {
    workspaceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Workspace', required: true, index: true },
    name: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    isAnnouncement: { type: Boolean, default: false },
    createdAt: { type: Date, default: () => new Date() },
  },
  { versionKey: false }
);

channelSchema.index({ workspaceId: 1, name: 1 }, { unique: true });

const Channel = mongoose.model('Channel', channelSchema);

module.exports = { Channel };

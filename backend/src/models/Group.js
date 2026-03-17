const mongoose = require('mongoose');

const groupSchema = new mongoose.Schema(
  {
    workspaceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Workspace', required: true, index: true },
    name: { type: String, required: true, trim: true },
    iconUrl: { type: String, trim: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    memberIds: { type: [mongoose.Schema.Types.ObjectId], ref: 'User', default: [], index: true },
    createdAt: { type: Date, default: () => new Date() },
  },
  { versionKey: false }
);

groupSchema.index({ workspaceId: 1, name: 1 });
groupSchema.index({ workspaceId: 1, memberIds: 1 });

const Group = mongoose.model('Group', groupSchema);

module.exports = { Group };

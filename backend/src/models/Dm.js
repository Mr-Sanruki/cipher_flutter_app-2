const mongoose = require('mongoose');

const dmSchema = new mongoose.Schema(
  {
    workspaceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Workspace', required: true, index: true },
    memberIds: { type: [mongoose.Schema.Types.ObjectId], ref: 'User', required: true, index: true },
    memberKey: { type: String, required: true, index: true },
    lastMessage: { type: String },
    lastMessageAt: { type: Date },
    createdAt: { type: Date, default: () => new Date() },
  },
  { versionKey: false }
);

dmSchema.index({ workspaceId: 1, memberKey: 1 }, { unique: true });

const Dm = mongoose.model('Dm', dmSchema);

module.exports = { Dm };

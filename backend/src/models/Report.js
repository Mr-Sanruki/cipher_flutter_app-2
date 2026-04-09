const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema(
  {
    workspaceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Workspace', required: true, index: true },
    reporterId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    targetType: { type: String, required: true, enum: ['message', 'user'], index: true },

    chatType: { type: String, enum: ['channel', 'dm', 'group'] },
    chatId: { type: mongoose.Schema.Types.ObjectId },
    messageId: { type: mongoose.Schema.Types.ObjectId },
    targetUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },

    reason: { type: String, required: true },
    details: { type: String },

    createdAt: { type: Date, default: () => new Date(), index: true },
    status: { type: String, default: 'open', enum: ['open', 'resolved'] },
    resolvedAt: { type: Date },
    resolvedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { versionKey: false }
);

reportSchema.index({ workspaceId: 1, createdAt: -1 });

const Report = mongoose.model('Report', reportSchema);

module.exports = { Report };

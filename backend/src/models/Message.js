const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    workspaceId: { type: mongoose.Schema.Types.ObjectId, ref: 'Workspace', required: true, index: true },
    chatType: { type: String, required: true, enum: ['channel', 'dm', 'group'], index: true },
    chatId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },

    senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    senderName: { type: String, required: true },
    senderAvatar: { type: String },

    content: { type: String, required: true },
    contentSearch: { type: String },
    type: { type: String, default: 'text' },
    fileUrl: { type: String },
    fileName: { type: String },
    fileSize: { type: String },

    isEdited: { type: Boolean, default: false },
    isDeleted: { type: Boolean, default: false },
    pinnedAt: { type: Date },
    pinnedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    threadCount: { type: Number, default: 0 },

    parentMessageId: { type: mongoose.Schema.Types.ObjectId, index: true },

    deliveredTo: { type: Map, of: Date, default: {} },
    readBy: { type: Map, of: Date, default: {} },

    reactions: { type: Map, of: [String], default: {} },

    forwardOf: {
      messageId: { type: mongoose.Schema.Types.ObjectId },
      chatType: { type: String, enum: ['channel', 'dm', 'group'] },
      chatId: { type: mongoose.Schema.Types.ObjectId },
      senderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      content: { type: String },
      type: { type: String },
      fileUrl: { type: String },
      fileName: { type: String },
      fileSize: { type: String },
      createdAt: { type: Date },
    },

    createdAt: { type: Date, default: () => new Date(), index: true },
    editedAt: { type: Date },
  },
  { versionKey: false }
);

messageSchema.index({ chatType: 1, chatId: 1, createdAt: -1 });
messageSchema.index({ chatType: 1, chatId: 1, pinnedAt: -1 });
messageSchema.index({ parentMessageId: 1, createdAt: 1 });
messageSchema.index({ contentSearch: 'text' });

const Message = mongoose.model('Message', messageSchema);

module.exports = { Message };

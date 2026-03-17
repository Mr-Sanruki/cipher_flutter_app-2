const mongoose = require('mongoose');

const chatClearSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    chatType: { type: String, required: true, index: true },
    chatId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    clearedAt: { type: Date, required: true },
  },
  { versionKey: false }
);

chatClearSchema.index({ userId: 1, chatType: 1, chatId: 1 }, { unique: true });

const ChatClear = mongoose.model('ChatClear', chatClearSchema);

module.exports = { ChatClear };

const mongoose = require('mongoose');

const chatHideSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    chatType: { type: String, required: true, index: true },
    chatId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
    hiddenAt: { type: Date, required: true },
  },
  { versionKey: false }
);

chatHideSchema.index({ userId: 1, chatType: 1, chatId: 1 }, { unique: true });

const ChatHide = mongoose.model('ChatHide', chatHideSchema);

module.exports = { ChatHide };

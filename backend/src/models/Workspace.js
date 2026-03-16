const mongoose = require('mongoose');

const workspaceSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    description: { type: String, trim: true },
    iconUrl: { type: String, trim: true },
    ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    memberIds: { type: [mongoose.Schema.Types.ObjectId], ref: 'User', default: [], index: true },
    adminIds: { type: [mongoose.Schema.Types.ObjectId], ref: 'User', default: [] },
    memberRoles: { type: Map, of: String, default: {} },
    inviteCode: { type: String, required: true, unique: true, uppercase: true, trim: true, index: true },
    createdAt: { type: Date, default: () => new Date() },
  },
  { versionKey: false }
);

const Workspace = mongoose.model('Workspace', workspaceSchema);

module.exports = { Workspace };

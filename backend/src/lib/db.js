const mongoose = require('mongoose');

async function connectDb() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is required');

  await mongoose.connect(uri, {
    serverSelectionTimeoutMS: 15000,
  });
}

module.exports = { connectDb };

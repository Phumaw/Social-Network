const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    username: { type: String, lowercase: true, trim: true, unique: true, sparse: true },
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    passwordResetCodeHash: { type: String, default: null },
    passwordResetExpiresAt: { type: Date, default: null },
    passwordResetSentAt: { type: Date, default: null },
    passwordResetAttempts: { type: Number, default: 0 },
    address: { type: String, default: '' },
    profileImage: { type: String, default: '' },
    bannerImage: { type: String, default: '' },
    bio: { type: String, default: '' },
    isPrivate: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);
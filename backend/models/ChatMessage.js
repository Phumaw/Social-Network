const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema(
  {
    from: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    to: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    text: { type: String, default: '', maxlength: 2000 },
    imageUrl: { type: String, default: '' },
    mediaType: { type: String, enum: ['', 'image', 'video'], default: '' },
  },
  { timestamps: true }
);

chatMessageSchema.index({ from: 1, to: 1, createdAt: -1 });
chatMessageSchema.index({ to: 1, from: 1, createdAt: -1 });

module.exports = mongoose.model('ChatMessage', chatMessageSchema);

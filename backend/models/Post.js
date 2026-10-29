const mongoose = require('mongoose');

const postSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    community: { type: mongoose.Schema.Types.ObjectId, ref: 'Community', default: null },
    caption: { type: String, required: true },
    imageUrl: { type: String, default: '' },
    mediaType: { type: String, enum: ['image', 'video'], default: 'image' },
    location: { type: String, default: '' },
    tags: [{ type: String }],
    reactions: [
      {
        user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
        type: { type: String, required: true },
        createdAt: { type: Date, default: Date.now }
      }
    ],
    comments: [
      {
        user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        text: { type: String, required: true },
        createdAt: { type: Date, default: Date.now }
      }
    ]
  },
  { timestamps: true }
);

postSchema.index({ community: 1, createdAt: -1 });

module.exports = mongoose.model('Post', postSchema);
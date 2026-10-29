const mongoose = require('mongoose');

const postReportSchema = new mongoose.Schema(
  {
    post: { type: mongoose.Schema.Types.ObjectId, ref: 'Post', required: true },
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    reason: {
      type: String,
      enum: ['Inappropriate content', 'Spam', 'Harassment', 'False information', 'Other'],
      required: true,
    },
  },
  { timestamps: true }
);

postReportSchema.index({ post: 1, user: 1 }, { unique: true });

module.exports = mongoose.model('PostReport', postReportSchema);

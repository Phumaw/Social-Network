const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const {
  getPosts,
  createPost,
  updatePost,
  deletePost,
  setReaction,
  reportPost,
  addComment,
  deleteComment,
} = require('../controllers/postController');
const authMiddleware = require('../middleware/authMiddleware');

const uploadDirectory = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadDirectory, { recursive: true });

const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDirectory,
    filename: (req, file, callback) => {
      const extension = {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/gif': '.gif',
        'video/mp4': '.mp4',
        'video/quicktime': '.mov',
        'video/webm': '.webm',
      }[file.mimetype];
      callback(null, `${crypto.randomUUID()}${extension}`);
    },
  }),
  limits: { fileSize: 100 * 1024 * 1024 },
  fileFilter: (req, file, callback) => {
    if (![
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'video/mp4',
      'video/quicktime',
      'video/webm',
    ].includes(file.mimetype)) {
      return callback(new Error('รองรับรูป JPG, PNG, WEBP, GIF และวิดีโอ MP4, MOV, WEBM'));
    }
    callback(null, true);
  },
});

router.use(authMiddleware);
router.get('/', getPosts);
router.post('/', (req, res, next) => {
  upload.single('media')(req, res, (error) => {
    if (error) return res.status(400).json({ message: error.message });
    next();
  });
}, createPost);
router.put('/:id', (req, res, next) => {
  upload.single('media')(req, res, (error) => {
    if (error) return res.status(400).json({ message: error.message });
    next();
  });
}, updatePost);
router.delete('/:id', deletePost);
router.put('/:id/reaction', setReaction);
router.post('/:id/report', reportPost);
router.post('/:id/comments', addComment);
router.delete('/:id/comments/:commentId', deleteComment);

module.exports = router;
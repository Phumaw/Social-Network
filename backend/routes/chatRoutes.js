const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const authMiddleware = require('../middleware/authMiddleware');
const {
  getContacts,
  getConversations,
  getMessages,
  sendMessage,
  getNotifications,
  markNotificationsRead,
} = require('../controllers/chatController');

const router = express.Router();
const uploadDirectory = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadDirectory, { recursive: true });

const mediaExtensions = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'video/webm': '.webm',
};
const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDirectory,
    filename: (req, file, callback) => {
      callback(null, `${crypto.randomUUID()}${imageExtensions[file.mimetype] || ''}`);
    },
  }),
  limits: { fileSize: 100 * 1024 * 1024 },
  fileFilter: (req, file, callback) => {
    if (!mediaExtensions[file.mimetype]) {
      return callback(new Error('รองรับรูป JPG, PNG, WEBP, GIF และวิดีโอ MP4, MOV, WEBM'));
    }
    callback(null, true);
  },
});

router.use(authMiddleware);
router.get('/users', getContacts);
router.get('/conversations', getConversations);
router.get('/conversations/:userId/messages', getMessages);
router.post('/conversations/:userId/messages', (req, res, next) => {
  upload.single('media')(req, res, (error) => {
    if (error) return res.status(400).json({ message: error.message });
    next();
  });
}, sendMessage);
router.get('/notifications', getNotifications);
router.put('/notifications/read', markNotificationsRead);

module.exports = router;

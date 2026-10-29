const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const {
  register,
  login,
  requestPasswordReset,
  resetPassword,
  getMe,
  updateProfile,
  deleteAccount,
  setFollow,
  unfollow,
  getFollowStats,
  searchUsers,
  getPublicProfile,
  getFollowRequests,
  respondToFollowRequest,
} = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

const uploadDirectory = path.join(__dirname, '..', 'uploads');
fs.mkdirSync(uploadDirectory, { recursive: true });
const imageExtensions = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
};
const profileUpload = multer({
  storage: multer.diskStorage({
    destination: uploadDirectory,
    filename: (req, file, callback) => {
      callback(null, `${crypto.randomUUID()}${imageExtensions[file.mimetype] || ''}`);
    },
  }),
  limits: { fileSize: 10 * 1024 * 1024, files: 2 },
  fileFilter: (req, file, callback) => {
    if (!imageExtensions[file.mimetype]) {
      return callback(new Error('รองรับไฟล์ JPG, PNG, WEBP หรือ GIF เท่านั้น'));
    }
    callback(null, true);
  },
});

const uploadProfileImages = (req, res, next) => {
  profileUpload.fields([
    { name: 'profileImage', maxCount: 1 },
    { name: 'bannerImage', maxCount: 1 },
  ])(req, res, (error) => {
    if (error) return res.status(400).json({ message: error.message });
    next();
  });
};

router.post('/register', register);
router.post('/login', login);
router.post('/forgot-password', requestPasswordReset);
router.post('/reset-password', resetPassword);
router.get('/me', authMiddleware, getMe);
router.get('/users', authMiddleware, searchUsers);
router.get('/users/:userId', authMiddleware, getPublicProfile);
router.get('/follow-requests', authMiddleware, getFollowRequests);
router.put('/follow-requests/:requestId', authMiddleware, respondToFollowRequest);
router.get('/follow-stats', authMiddleware, getFollowStats);
router.put('/follow/:userId', authMiddleware, setFollow);
router.delete('/follow/:userId', authMiddleware, unfollow);
router.put('/profile', authMiddleware, uploadProfileImages, updateProfile);
router.delete('/account', authMiddleware, deleteAccount);

module.exports = router;
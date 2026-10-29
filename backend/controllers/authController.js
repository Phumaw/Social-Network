const User = require('../models/User');
const mongoose = require('mongoose');
const Post = require('../models/Post');
const PostReport = require('../models/PostReport');
const ChatMessage = require('../models/ChatMessage');
const Notification = require('../models/Notification');
const Follow = require('../models/Follow');
const Community = require('../models/Community');
const FollowRequest = require('../models/FollowRequest');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const uploadsDirectory = path.join(__dirname, '..', 'uploads');

const removeUploadedImage = async (imageUrl) => {
  if (typeof imageUrl !== 'string' || !imageUrl.startsWith('/uploads/')) return;
  try {
    await fs.unlink(path.join(uploadsDirectory, path.basename(imageUrl)));
  } catch (error) {
    if (error.code !== 'ENOENT') console.error(`Could not remove profile image: ${error.message}`);
  }
};

const publicUser = (user) => ({
  id: user._id,
  name: user.name,
  username: user.username || '',
  email: user.email,
  address: user.address,
  profileImage: user.profileImage,
  bannerImage: user.bannerImage,
  bio: user.bio,
  isPrivate: user.isPrivate,
});

exports.register = async (req, res) => {
  try {
    const username = typeof req.body.username === 'string'
      ? req.body.username.trim().toLowerCase()
      : '';
    const name = typeof req.body.name === 'string' && req.body.name.trim()
      ? req.body.name.trim()
      : username;
    const email = typeof req.body.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    const address = typeof req.body.address === 'string' ? req.body.address.trim() : '';

    if (!email || !/^[a-z0-9_]{3,24}$/.test(username) || password.length < 6) {
      return res.status(400).json({
        message: 'กรุณากรอกอีเมล ชื่อผู้ใช้ (3-24 ตัวอักษร ใช้ a-z, 0-9 หรือ _) และรหัสผ่านอย่างน้อย 6 ตัวอักษร',
      });
    }

    const existingUser = await User.findOne({ $or: [{ email }, { username }] });
    if (existingUser) {
      return res.status(409).json({ message: 'อีเมลหรือชื่อผู้ใช้นี้ถูกใช้งานแล้ว' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await User.create({ name, username, email, password: hashedPassword, address });
    res.status(201).json({ message: 'ลงทะเบียนสำเร็จ', user: publicUser(user) });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ message: 'อีเมลหรือชื่อผู้ใช้นี้ถูกใช้งานแล้ว' });
    }
    res.status(500).json({ message: error.message });
  }
};

exports.login = async (req, res) => {
  try {
    const identifier = typeof req.body.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : typeof req.body.username === 'string'
      ? req.body.username.trim().toLowerCase()
      : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    const user = await User.findOne({
      $or: [{ username: identifier }, { email: identifier }],
    });

    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ message: 'เข้าสู่ระบบสำเร็จ', token, user: publicUser(user) });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.requestPasswordReset = async (req, res) => {
  try {
    const email = typeof req.body.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : '';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ message: 'กรุณากรอกอีเมลให้ถูกต้อง' });
    }

    const smtpHost = process.env.SMTP_HOST;
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;
    const smtpFrom = process.env.SMTP_FROM || smtpUser;
    if (!smtpHost || !smtpUser || !smtpPass || !smtpFrom) {
      return res.status(503).json({
        message: 'ระบบส่งอีเมลยังไม่ได้ตั้งค่า กรุณาติดต่อผู้ดูแลระบบ',
      });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.json({
        message: 'หากอีเมลนี้ลงทะเบียนไว้ ระบบจะส่งรหัสยืนยันไปให้',
      });
    }

    const now = new Date();
    if (
      user.passwordResetSentAt &&
      now.getTime() - user.passwordResetSentAt.getTime() < 60_000
    ) {
      return res.status(429).json({
        message: 'กรุณารอ 1 นาทีก่อนขอรหัสยืนยันใหม่',
      });
    }

    const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
    user.passwordResetCodeHash = await bcrypt.hash(code, 10);
    user.passwordResetExpiresAt = new Date(now.getTime() + 10 * 60_000);
    user.passwordResetSentAt = now;
    user.passwordResetAttempts = 0;
    await user.save();

    try {
      const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: Number(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_SECURE === 'true',
        auth: { user: smtpUser, pass: smtpPass },
      });
      await transporter.sendMail({
        from: smtpFrom,
        to: user.email,
        subject: 'รหัสเปลี่ยนรหัสผ่าน Social Network',
        text: `รหัสยืนยันเปลี่ยนรหัสผ่านของคุณคือ ${code}\nรหัสนี้ใช้ได้ 10 นาที หากคุณไม่ได้ร้องขอ สามารถละเว้นอีเมลนี้ได้`,
        html: `<p>รหัสยืนยันเปลี่ยนรหัสผ่านของคุณคือ</p><p style="font-size:28px;font-weight:bold;letter-spacing:6px">${code}</p><p>รหัสนี้ใช้ได้ 10 นาที หากคุณไม่ได้ร้องขอ สามารถละเว้นอีเมลนี้ได้</p>`,
      });
    } catch (error) {
      user.passwordResetCodeHash = null;
      user.passwordResetExpiresAt = null;
      user.passwordResetSentAt = null;
      user.passwordResetAttempts = 0;
      await user.save();
      console.error(`Password reset email could not be sent: ${error.message}`);
      return res.status(502).json({
        message: 'ส่งอีเมลไม่สำเร็จ กรุณาตรวจสอบการตั้งค่าอีเมลหรือลองใหม่ภายหลัง',
      });
    }

    res.json({ message: 'หากอีเมลนี้ลงทะเบียนไว้ ระบบจะส่งรหัสยืนยันไปให้' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.resetPassword = async (req, res) => {
  try {
    const email = typeof req.body.email === 'string'
      ? req.body.email.trim().toLowerCase()
      : '';
    const code = typeof req.body.code === 'string' ? req.body.code.trim() : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !/^\d{6}$/.test(code)) {
      return res.status(400).json({ message: 'อีเมลหรือรหัสยืนยันไม่ถูกต้อง' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'รหัสผ่านใหม่ต้องมีความยาวอย่างน้อย 6 ตัวอักษร' });
    }

    const user = await User.findOne({ email });
    const now = new Date();
    if (
      !user ||
      !user.passwordResetCodeHash ||
      !user.passwordResetExpiresAt ||
      user.passwordResetExpiresAt <= now
    ) {
      return res.status(400).json({ message: 'รหัสยืนยันไม่ถูกต้องหรือหมดอายุ กรุณาขอรหัสใหม่' });
    }
    if (user.passwordResetAttempts >= 5) {
      user.passwordResetCodeHash = null;
      user.passwordResetExpiresAt = null;
      user.passwordResetAttempts = 0;
      await user.save();
      return res.status(429).json({ message: 'กรอกรหัสผิดเกินกำหนด กรุณาขอรหัสยืนยันใหม่' });
    }
    if (!(await bcrypt.compare(code, user.passwordResetCodeHash))) {
      user.passwordResetAttempts += 1;
      await user.save();
      return res.status(400).json({ message: 'รหัสยืนยันไม่ถูกต้อง' });
    }

    user.password = await bcrypt.hash(password, 10);
    user.passwordResetCodeHash = null;
    user.passwordResetExpiresAt = null;
    user.passwordResetSentAt = null;
    user.passwordResetAttempts = 0;
    await user.save();
    res.json({ message: 'เปลี่ยนรหัสผ่านสำเร็จ กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('-password');
    if (!user) return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });
    res.json(publicUser(user));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.searchUsers = async (req, res) => {
  try {
    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    if (!query) return res.json([]);
    const escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const users = await User.find({
      _id: { $ne: req.userId },
      $or: [
        { name: { $regex: escapedQuery, $options: 'i' } },
        { username: { $regex: escapedQuery.replace(/^@/, ''), $options: 'i' } },
      ],
    })
      .select('name username profileImage bio isPrivate')
      .sort({ name: 1 })
      .limit(50);
    const [follows, requests] = await Promise.all([
      Follow.find({
        follower: req.userId,
        following: { $in: users.map((user) => user._id) },
      }).select('following'),
      FollowRequest.find({
        requester: req.userId,
        recipient: { $in: users.map((user) => user._id) },
        status: 'pending',
      }).select('recipient'),
    ]);
    const followingIds = new Set(follows.map((follow) => String(follow.following)));
    const pendingIds = new Set(requests.map((request) => String(request.recipient)));
    res.json(users.map((user) => ({
      id: user._id,
      name: user.name,
      username: user.username || '',
      profileImage: user.profileImage,
      bio: user.bio,
      isPrivate: user.isPrivate,
      isFollowing: followingIds.has(String(user._id)),
      followRequestPending: pendingIds.has(String(user._id)),
    })));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getPublicProfile = async (req, res) => {
  try {
    const userId = req.params.userId;
    if (!mongoose.isValidObjectId(userId)) {
      return res.status(400).json({ message: 'บัญชีผู้ใช้ไม่ถูกต้อง' });
    }
    const user = await User.findById(userId).select(
      'name username profileImage bannerImage bio isPrivate',
    );
    if (!user) return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });

    const isSelf = String(user._id) === req.userId;
    const [follow, outgoingRequest, counts] = await Promise.all([
      Follow.findOne({ follower: req.userId, following: user._id }).select('_id'),
      FollowRequest.findOne({
        requester: req.userId,
        recipient: user._id,
        status: 'pending',
      }).select('_id'),
      Follow.aggregate([
        {
          $match: {
            $or: [{ follower: user._id }, { following: user._id }],
          },
        },
        {
          $group: {
            _id: null,
            followers: {
              $sum: { $cond: [{ $eq: ['$following', user._id] }, 1, 0] },
            },
            following: {
              $sum: { $cond: [{ $eq: ['$follower', user._id] }, 1, 0] },
            },
          },
        },
      ]),
    ]);
    const isFollowing = Boolean(follow);
    const canViewPrivateContent = isSelf || !user.isPrivate || isFollowing;
    res.json({
      user: {
        id: user._id,
        name: user.name,
        username: user.username || '',
        profileImage: user.profileImage,
        bannerImage: canViewPrivateContent ? user.bannerImage : '',
        bio: user.bio,
        isPrivate: user.isPrivate,
      },
      isSelf,
      isFollowing,
      followRequestPending: Boolean(outgoingRequest),
      canViewPrivateContent,
      followersCount: canViewPrivateContent ? (counts[0]?.followers ?? 0) : null,
      followingCount: canViewPrivateContent ? (counts[0]?.following ?? 0) : null,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.setFollow = async (req, res) => {
  const { userId } = req.params;
  if (!mongoose.isValidObjectId(userId)) {
    return res.status(400).json({ message: 'บัญชีผู้ใช้ไม่ถูกต้อง' });
  }
  if (userId === req.userId) {
    return res.status(400).json({ message: 'ไม่สามารถติดตามบัญชีของตนเองได้' });
  }

  try {
    const target = await User.findById(userId).select('_id isPrivate');
    if (!target) return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });

    if (target.isPrivate) {
      const existingFollow = await Follow.exists({
        follower: req.userId,
        following: target._id,
      });
      if (existingFollow) {
        return res.json({ following: true, requestPending: false });
      }
      const request = await FollowRequest.findOneAndUpdate(
        { requester: req.userId, recipient: target._id },
        { $set: { status: 'pending' }, $setOnInsert: { requester: req.userId, recipient: target._id } },
        { upsert: true, new: true, setDefaultsOnInsert: true },
      );
      await Notification.updateOne(
        {
          recipient: target._id,
          actor: req.userId,
          message: 'ส่งคำขอติดตาม',
          readAt: null,
        },
        {
          $setOnInsert: {
            recipient: target._id,
            actor: req.userId,
            message: 'ส่งคำขอติดตาม',
          },
        },
        { upsert: true },
      );
      return res.json({
        following: false,
        requestPending: request.status === 'pending',
      });
    }

    await Follow.updateOne(
      { follower: req.userId, following: target._id },
      { $setOnInsert: { follower: req.userId, following: target._id } },
      { upsert: true },
    );
    res.json({ following: true, requestPending: false });
  } catch (error) {
    if (error.code === 11000) {
      const [following, requestPending] = await Promise.all([
        Follow.exists({ follower: req.userId, following: userId }),
        FollowRequest.exists({
          requester: req.userId,
          recipient: userId,
          status: 'pending',
        }),
      ]);
      return res.json({ following: Boolean(following), requestPending: Boolean(requestPending) });
    }
    res.status(500).json({ message: error.message });
  }
};

exports.unfollow = async (req, res) => {
  const { userId } = req.params;
  if (!mongoose.isValidObjectId(userId)) {
    return res.status(400).json({ message: 'บัญชีผู้ใช้ไม่ถูกต้อง' });
  }

  try {
    await Follow.deleteOne({ follower: req.userId, following: userId });
    await FollowRequest.deleteOne({
      requester: req.userId,
      recipient: userId,
      status: 'pending',
    });
    await Notification.deleteMany({
      recipient: userId,
      actor: req.userId,
      message: 'ส่งคำขอติดตาม',
      readAt: null,
    });
    res.json({ following: false, requestPending: false });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getFollowRequests = async (req, res) => {
  try {
    const requests = await FollowRequest.find({
      recipient: req.userId,
      status: 'pending',
    })
      .populate('requester', 'name username profileImage bio')
      .sort({ createdAt: -1 })
      .limit(100);
    res.json(requests.map((request) => ({
      id: request._id,
      user: {
        id: request.requester._id,
        name: request.requester.name,
        username: request.requester.username || '',
        profileImage: request.requester.profileImage,
        bio: request.requester.bio,
      },
      createdAt: request.createdAt,
    })));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.respondToFollowRequest = async (req, res) => {
  try {
    const requestId = req.params.requestId;
    if (!mongoose.isValidObjectId(requestId)) {
      return res.status(400).json({ message: 'คำขอติดตามไม่ถูกต้อง' });
    }
    const action = req.body.action;
    if (!['accept', 'decline'].includes(action)) {
      return res.status(400).json({ message: 'การตอบรับคำขอไม่ถูกต้อง' });
    }
    const request = await FollowRequest.findOne({
      _id: requestId,
      recipient: req.userId,
      status: 'pending',
    });
    if (!request) return res.status(404).json({ message: 'ไม่พบคำขอติดตามนี้' });

    if (action === 'accept') {
      await Follow.updateOne(
        { follower: request.requester, following: request.recipient },
        {
          $setOnInsert: {
            follower: request.requester,
            following: request.recipient,
          },
        },
        { upsert: true },
      );
    }
    request.status = action === 'accept' ? 'accepted' : 'declined';
    await request.save();
    await Notification.deleteOne({
      recipient: req.userId,
      actor: request.requester,
      message: 'ส่งคำขอติดตาม',
      readAt: null,
    });
    res.json({ status: request.status });
  } catch (error) {
    if (error.code === 11000) return res.json({ status: 'accepted' });
    res.status(500).json({ message: error.message });
  }
};

exports.getFollowStats = async (req, res) => {
  try {
    const [followers, following] = await Promise.all([
      Follow.find({ following: req.userId })
        .sort({ createdAt: -1 })
        .populate('follower', 'name username profileImage'),
      Follow.find({ follower: req.userId })
        .sort({ createdAt: -1 })
        .populate('following', 'name username profileImage'),
    ]);

    const publicFollowUser = (user) => ({
      id: user._id,
      name: user.name,
      username: user.username || '',
      profileImage: user.profileImage,
    });
    res.json({
      followers: followers.map((follow) => publicFollowUser(follow.follower)),
      following: following.map((follow) => publicFollowUser(follow.following)),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.updateProfile = async (req, res) => {
  try {
    const updates = {};
    for (const field of ['name', 'bio', 'address']) {
      if (typeof req.body[field] === 'string') updates[field] = req.body[field].trim();
    }
    if (typeof req.body.isPrivate === 'boolean') {
      updates.isPrivate = req.body.isPrivate;
    } else if (req.body.isPrivate === 'true' || req.body.isPrivate === 'false') {
      updates.isPrivate = req.body.isPrivate === 'true';
    }
    if (updates.name !== undefined && !updates.name) {
      await Promise.all([
        removeUploadedImage(req.files?.profileImage?.[0]
          ? `/uploads/${req.files.profileImage[0].filename}`
          : ''),
        removeUploadedImage(req.files?.bannerImage?.[0]
          ? `/uploads/${req.files.bannerImage[0].filename}`
          : ''),
      ]);
      return res.status(400).json({ message: 'กรุณาระบุชื่อผู้ใช้' });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      await Promise.all([
        removeUploadedImage(req.files?.profileImage?.[0]
          ? `/uploads/${req.files.profileImage[0].filename}`
          : ''),
        removeUploadedImage(req.files?.bannerImage?.[0]
          ? `/uploads/${req.files.bannerImage[0].filename}`
          : ''),
      ]);
      return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });
    }
    if (user.isPrivate && updates.isPrivate === false) {
      const pendingRequests = await FollowRequest.find({
        recipient: user._id,
        status: 'pending',
      });
      await Promise.all(pendingRequests.map(async (request) => {
        await Follow.updateOne(
          { follower: request.requester, following: user._id },
          {
            $setOnInsert: {
              follower: request.requester,
              following: user._id,
            },
          },
          { upsert: true },
        );
        request.status = 'accepted';
        await request.save();
      }));
      await Notification.deleteMany({
        recipient: user._id,
        message: 'ส่งคำขอติดตาม',
        readAt: null,
      });
    }
    const previousProfileImage = user.profileImage;
    const previousBannerImage = user.bannerImage;
    Object.assign(user, updates);
    if (req.files?.profileImage?.[0]) {
      user.profileImage = `/uploads/${req.files.profileImage[0].filename}`;
    }
    if (req.files?.bannerImage?.[0]) {
      user.bannerImage = `/uploads/${req.files.bannerImage[0].filename}`;
    }
    await user.save();
    if (req.files?.profileImage?.[0]) await removeUploadedImage(previousProfileImage);
    if (req.files?.bannerImage?.[0]) await removeUploadedImage(previousBannerImage);
    res.json(publicUser(user));
  } catch (error) {
    await Promise.all([
      removeUploadedImage(req.files?.profileImage?.[0]
        ? `/uploads/${req.files.profileImage[0].filename}`
        : ''),
      removeUploadedImage(req.files?.bannerImage?.[0]
        ? `/uploads/${req.files.bannerImage[0].filename}`
        : ''),
    ]);
    if (error.code === 11000) {
      return res.status(409).json({ message: 'อีเมลหรือชื่อผู้ใช้นี้ถูกใช้งานแล้ว' });
    }
    res.status(500).json({ message: error.message });
  }
};

exports.deleteAccount = async (req, res) => {
  try {
    const password = typeof req.body.password === 'string'
      ? req.body.password
      : '';
    if (!password) {
      return res.status(400).json({ message: 'กรุณากรอกรหัสผ่านเพื่อยืนยันการลบบัญชี' });
    }

    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });
    if (!(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ message: 'รหัสผ่านไม่ถูกต้อง' });
    }

    const communities = await Community.find({ createdBy: user._id }).select('_id');
    const communityIds = communities.map((community) => community._id);
    const [posts, messages] = await Promise.all([
      Post.find({
        $or: [{ user: user._id }, { community: { $in: communityIds } }],
      }).select('_id imageUrl'),
      ChatMessage.find({
        $or: [{ from: user._id }, { to: user._id }],
      }).select('imageUrl'),
    ]);
    const postIds = posts.map((post) => post._id);
    const uploadedImages = [
      user.profileImage,
      user.bannerImage,
      ...posts.map((post) => post.imageUrl),
      ...messages.map((message) => message.imageUrl),
    ];

    await PostReport.deleteMany({
      $or: [{ user: user._id }, { post: { $in: postIds } }],
    });
    await Follow.deleteMany({
      $or: [{ follower: user._id }, { following: user._id }],
    });
    await FollowRequest.deleteMany({
      $or: [{ requester: user._id }, { recipient: user._id }],
    });
    await ChatMessage.deleteMany({
      $or: [{ from: user._id }, { to: user._id }],
    });
    await Community.deleteMany({ createdBy: user._id });
    await Community.updateMany(
      { createdBy: { $ne: user._id } },
      { $pull: { members: { user: user._id } } },
    );
    await Notification.deleteMany({
      $or: [{ recipient: user._id }, { actor: user._id }],
    });
    await Post.updateMany(
      { user: { $ne: user._id } },
      {
        $pull: {
          reactions: { user: user._id },
          comments: { user: user._id },
        },
      },
    );
    await Post.deleteMany({
      $or: [{ user: user._id }, { community: { $in: communityIds } }],
    });
    await user.deleteOne();

    await Promise.all(uploadedImages.map(removeUploadedImage));
    res.json({ message: 'ลบบัญชีและข้อมูลที่เกี่ยวข้องแล้ว' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

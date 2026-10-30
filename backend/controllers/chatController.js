const mongoose = require('mongoose');
const ChatMessage = require('../models/ChatMessage');
const Notification = require('../models/Notification');
const User = require('../models/User');
const Post = require('../models/Post');
const Follow = require('../models/Follow');
const Community = require('../models/Community');
const fs = require('fs/promises');
const path = require('path');

const uploadsDirectory = path.join(__dirname, '..', 'uploads');

const removeUploadedMedia = async (file) => {
  if (!file) return;
  try {
    await fs.unlink(path.join(uploadsDirectory, path.basename(file)));
  } catch (error) {
    if (error.code !== 'ENOENT') console.error(`Could not remove chat media: ${error.message}`);
  }
};

const canViewSharedPost = async (post, userId) => {
  if (!post) return false;
  if (post.community) {
    return Boolean(await Community.exists({
      _id: post.community,
      'members.user': userId,
    }));
  }
  const authorId = String(post.user?._id ?? post.user);
  if (authorId === userId) return true;
  const author = await User.findById(authorId).select('isPrivate');
  if (!author) return false;
  if (!author.isPrivate) return true;
  return Boolean(await Follow.exists({
    follower: userId,
    following: author._id,
  }));
};

exports.getContacts = async (req, res) => {
  try {
    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const filter = { _id: { $ne: req.userId } };
    if (query) {
      const escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      filter.name = { $regex: escapedQuery, $options: 'i' };
    }
    const users = await User.find(filter)
      .select('name profileImage bio')
      .sort({ name: 1 })
      .limit(100);
    res.json(users);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getConversations = async (req, res) => {
  try {
    const messages = await ChatMessage.find({
      $or: [{ from: req.userId }, { to: req.userId }],
    })
      .sort({ createdAt: -1 })
      .limit(500)
      .populate('from', 'name profileImage')
      .populate('to', 'name profileImage');

    const conversations = new Map();
    for (const message of messages) {
      const otherUser = String(message.from._id) === req.userId ? message.to : message.from;
      const key = String(otherUser._id);
      if (!conversations.has(key)) {
        conversations.set(key, {
          user: otherUser,
          lastMessage: {
            text: message.text || (message.sharedPost ? 'แชร์โพสต์กับคุณ' : ''),
            imageUrl: message.imageUrl,
            mediaType: message.mediaType,
            from: String(message.from._id),
            createdAt: message.createdAt,
          },
        });
      }
    }
    res.json([...conversations.values()]);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getMessages = async (req, res) => {
  try {
    const otherUserId = req.params.userId;
    if (!mongoose.isValidObjectId(otherUserId)) {
      return res.status(400).json({ message: 'บัญชีผู้ใช้ไม่ถูกต้อง' });
    }
    const otherUser = await User.findById(otherUserId).select('_id');
    if (!otherUser) return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });

    const messages = await ChatMessage.find({
      $or: [
        { from: req.userId, to: otherUserId },
        { from: otherUserId, to: req.userId },
      ],
    })
      .sort({ createdAt: -1 })
      .limit(200)
      .populate('from', 'name profileImage')
      .populate('to', 'name profileImage');
    const messagesWithSharedPosts = await Promise.all(
      messages.reverse().map(async (message) => {
        const data = message.toObject();
        const sharedPostId = data.sharedPost ? String(data.sharedPost) : null;
        if (!sharedPostId) {
          data.sharedPost = null;
          data.sharedPostUnavailable = false;
          return data;
        }
        const sharedPost = await Post.findById(sharedPostId).populate(
          'user',
          'name profileImage',
        );
        if (!(await canViewSharedPost(sharedPost, req.userId))) {
          data.sharedPost = null;
          data.sharedPostUnavailable = true;
          return data;
        }
        data.sharedPost = sharedPost.toObject();
        data.sharedPostUnavailable = false;
        return data;
      }),
    );
    res.json(messagesWithSharedPosts);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const to = req.params.userId;
    const text = typeof req.body.text === 'string' ? req.body.text.trim() : '';
    const sharedPostId = typeof req.body.sharedPostId === 'string'
      ? req.body.sharedPostId.trim()
      : '';
    if (!mongoose.isValidObjectId(to) || to === req.userId) {
      await removeUploadedMedia(req.file?.filename);
      return res.status(400).json({ message: 'ผู้รับข้อความไม่ถูกต้อง' });
    }
    if (text.length > 2000) {
      await removeUploadedMedia(req.file?.filename);
      return res.status(400).json({ message: 'ข้อความต้องมีความยาวไม่เกิน 2000 ตัวอักษร' });
    }
    if (sharedPostId && !mongoose.isValidObjectId(sharedPostId)) {
      await removeUploadedMedia(req.file?.filename);
      return res.status(400).json({ message: 'โพสต์ที่แชร์ไม่ถูกต้อง' });
    }
    if (!text && !req.file && !sharedPostId) {
      return res.status(400).json({ message: 'กรุณาพิมพ์ข้อความ เลือกสื่อ หรือแชร์โพสต์' });
    }

    const recipient = await User.findById(to).select('_id');
    if (!recipient) {
      await removeUploadedMedia(req.file?.filename);
      return res.status(404).json({ message: 'ไม่พบบัญชีผู้รับ' });
    }
    if (sharedPostId) {
      const sharedPost = await Post.findById(sharedPostId);
      if (!sharedPost) {
        await removeUploadedMedia(req.file?.filename);
        return res.status(404).json({ message: 'ไม่พบโพสต์ที่แชร์' });
      }
      if (!(await canViewSharedPost(sharedPost, req.userId))) {
        await removeUploadedMedia(req.file?.filename);
        return res.status(403).json({ message: 'คุณไม่มีสิทธิ์แชร์โพสต์นี้' });
      }
    }
    const message = await ChatMessage.create({
      from: req.userId,
      to,
      text,
      imageUrl: req.file ? `/uploads/${req.file.filename}` : '',
      mediaType: req.file
        ? (req.file.mimetype.startsWith('video/') ? 'video' : 'image')
        : '',
      sharedPost: sharedPostId || null,
    });
    await Notification.create({
      recipient: to,
      actor: req.userId,
      message: text || (
        message.mediaType
          ? (message.mediaType === 'video' ? 'ส่งวิดีโอถึงคุณ' : 'ส่งรูปภาพถึงคุณ')
          : 'แชร์โพสต์กับคุณ'
      ),
    });
    await message.populate([
      { path: 'from', select: 'name profileImage' },
      { path: 'to', select: 'name profileImage' },
    ]);
    res.status(201).json(message);
  } catch (error) {
    await removeUploadedMedia(req.file?.filename);
    res.status(500).json({ message: error.message });
  }
};

exports.getNotifications = async (req, res) => {
  try {
    const notifications = await Notification.find({ recipient: req.userId })
      .populate('actor', 'name profileImage')
      .sort({ createdAt: -1 })
      .limit(100);
    res.json(notifications);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.markNotificationsRead = async (req, res) => {
  try {
    await Notification.updateMany(
      { recipient: req.userId, readAt: null },
      { $set: { readAt: new Date() } }
    );
    res.json({ message: 'อ่านการแจ้งเตือนแล้ว' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

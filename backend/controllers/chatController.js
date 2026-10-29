const mongoose = require('mongoose');
const ChatMessage = require('../models/ChatMessage');
const Notification = require('../models/Notification');
const User = require('../models/User');
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
            text: message.text,
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
    res.json(messages.reverse());
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const to = req.params.userId;
    const text = typeof req.body.text === 'string' ? req.body.text.trim() : '';
    if (!mongoose.isValidObjectId(to) || to === req.userId) {
      await removeUploadedMedia(req.file?.filename);
      return res.status(400).json({ message: 'ผู้รับข้อความไม่ถูกต้อง' });
    }
    if (text.length > 2000) {
      await removeUploadedMedia(req.file?.filename);
      return res.status(400).json({ message: 'ข้อความต้องมีความยาวไม่เกิน 2000 ตัวอักษร' });
    }
    if (!text && !req.file) {
      return res.status(400).json({ message: 'กรุณาพิมพ์ข้อความหรือเลือกสื่อ' });
    }

    const recipient = await User.findById(to).select('_id');
    if (!recipient) {
      await removeUploadedMedia(req.file?.filename);
      return res.status(404).json({ message: 'ไม่พบบัญชีผู้รับ' });
    }
    const message = await ChatMessage.create({
      from: req.userId,
      to,
      text,
      imageUrl: req.file ? `/uploads/${req.file.filename}` : '',
      mediaType: req.file
        ? (req.file.mimetype.startsWith('video/') ? 'video' : 'image')
        : '',
    });
    await Notification.create({
      recipient: to,
      actor: req.userId,
      message: text || (message.mediaType === 'video' ? 'ส่งวิดีโอถึงคุณ' : 'ส่งรูปภาพถึงคุณ'),
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

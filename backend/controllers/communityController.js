const mongoose = require('mongoose');
const Community = require('../models/Community');
const Post = require('../models/Post');
const PostReport = require('../models/PostReport');
const fs = require('fs/promises');
const path = require('path');

const uploadsDirectory = path.join(__dirname, '..', 'uploads');

const removeUploadedMedia = async (imageUrl) => {
  if (typeof imageUrl !== 'string' || !imageUrl.startsWith('/uploads/')) return;
  try {
    await fs.unlink(path.join(uploadsDirectory, path.basename(imageUrl)));
  } catch (error) {
    if (error.code !== 'ENOENT') console.error(`Could not remove community post media: ${error.message}`);
  }
};

const serializeCommunity = (community, userId) => {
  const member = community.members.find((item) => String(item.user?._id ?? item.user) === userId);
  return {
    ...community.toObject(),
    memberCount: community.members.length,
    isMember: Boolean(member),
    isAdmin: member?.role === 'admin',
  };
};

const getCommunity = async (id) => {
  if (!mongoose.isValidObjectId(id)) return null;
  return Community.findById(id).populate('createdBy', 'name profileImage');
};

exports.listCommunities = async (req, res) => {
  try {
    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const filter = {};
    if (query) {
      const escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      filter.name = { $regex: escapedQuery, $options: 'i' };
    }
    const communities = await Community.find(filter)
      .populate('createdBy', 'name profileImage')
      .sort({ updatedAt: -1 })
      .limit(100);
    res.json(communities.map((community) => serializeCommunity(community, req.userId)));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getCommunity = async (req, res) => {
  try {
    const community = await getCommunity(req.params.id);
    if (!community) return res.status(404).json({ message: 'ไม่พบกลุ่มหรือเพจนี้' });
    res.json(serializeCommunity(community, req.userId));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.createCommunity = async (req, res) => {
  try {
    const name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
    const description = typeof req.body.description === 'string'
      ? req.body.description.trim()
      : '';
    const type = req.body.type;
    if (!name || name.length > 80) {
      return res.status(400).json({ message: 'ชื่อกลุ่มหรือเพจต้องมีความยาว 1-80 ตัวอักษร' });
    }
    if (description.length > 500) {
      return res.status(400).json({ message: 'คำอธิบายต้องมีความยาวไม่เกิน 500 ตัวอักษร' });
    }
    if (!['group', 'page'].includes(type)) {
      return res.status(400).json({ message: 'ประเภทชุมชนไม่ถูกต้อง' });
    }
    const community = await Community.create({
      name,
      description,
      type,
      createdBy: req.userId,
      members: [{ user: req.userId, role: 'admin' }],
    });
    await community.populate('createdBy', 'name profileImage');
    res.status(201).json(serializeCommunity(community, req.userId));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.updateCommunity = async (req, res) => {
  try {
    const community = await getCommunity(req.params.id);
    if (!community) return res.status(404).json({ message: 'ไม่พบกลุ่มหรือเพจนี้' });
    if (String(community.createdBy._id) !== req.userId) {
      return res.status(403).json({ message: 'เฉพาะผู้สร้างเท่านั้นที่แก้ไขข้อมูลได้' });
    }

    if (typeof req.body.name === 'string') {
      const name = req.body.name.trim();
      if (!name || name.length > 80) {
        return res.status(400).json({ message: 'ชื่อกลุ่มหรือเพจต้องมีความยาว 1-80 ตัวอักษร' });
      }
      community.name = name;
    }
    if (typeof req.body.description === 'string') {
      const description = req.body.description.trim();
      if (description.length > 500) {
        return res.status(400).json({ message: 'คำอธิบายต้องมีความยาวไม่เกิน 500 ตัวอักษร' });
      }
      community.description = description;
    }
    if (req.body.type !== undefined) {
      if (!['group', 'page'].includes(req.body.type)) {
        return res.status(400).json({ message: 'ประเภทชุมชนไม่ถูกต้อง' });
      }
      community.type = req.body.type;
    }
    await community.save();
    res.json(serializeCommunity(community, req.userId));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.joinCommunity = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'กลุ่มหรือเพจไม่ถูกต้อง' });
    }
    let community = await Community.findOneAndUpdate(
      { _id: req.params.id, 'members.user': { $ne: req.userId } },
      { $push: { members: { user: req.userId, role: 'member' } } },
      { new: true },
    );
    if (!community) community = await Community.findById(req.params.id);
    if (!community) return res.status(404).json({ message: 'ไม่พบกลุ่มหรือเพจนี้' });
    res.json(serializeCommunity(community, req.userId));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.leaveCommunity = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'กลุ่มหรือเพจไม่ถูกต้อง' });
    }
    const community = await Community.findById(req.params.id);
    if (!community) return res.status(404).json({ message: 'ไม่พบกลุ่มหรือเพจนี้' });
    if (String(community.createdBy) === req.userId) {
      return res.status(400).json({ message: 'ผู้สร้างไม่สามารถออกจากชุมชนได้ กรุณาลบชุมชนแทน' });
    }
    community.members = community.members.filter((item) => String(item.user) !== req.userId);
    await community.save();
    res.json({ message: 'ออกจากชุมชนแล้ว' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.deleteCommunity = async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'กลุ่มหรือเพจไม่ถูกต้อง' });
    }
    const community = await Community.findById(req.params.id);
    if (!community) return res.status(404).json({ message: 'ไม่พบกลุ่มหรือเพจนี้' });
    if (String(community.createdBy) !== req.userId) {
      return res.status(403).json({ message: 'เฉพาะผู้สร้างเท่านั้นที่ลบได้' });
    }
    const posts = await Post.find({ community: community._id }).select('_id imageUrl');
    await PostReport.deleteMany({ post: { $in: posts.map((post) => post._id) } });
    await Post.deleteMany({ community: community._id });
    await community.deleteOne();
    await Promise.all(posts.map((post) => removeUploadedMedia(post.imageUrl)));
    res.json({ message: 'ลบชุมชนและโพสต์ภายในแล้ว' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

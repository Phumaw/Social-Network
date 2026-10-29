const Post = require('../models/Post');
const PostReport = require('../models/PostReport');
const Follow = require('../models/Follow');
const FollowRequest = require('../models/FollowRequest');
const User = require('../models/User');
const Community = require('../models/Community');
const mongoose = require('mongoose');
const fs = require('fs/promises');
const path = require('path');
const uploadsDirectory = path.join(__dirname, '..', 'uploads');

const removeUploadedImage = async (imageUrl) => {
  if (typeof imageUrl !== 'string' || !imageUrl.startsWith('/uploads/')) return;
  try {
    await fs.unlink(path.join(uploadsDirectory, path.basename(imageUrl)));
  } catch (error) {
    if (error.code !== 'ENOENT') console.error(`Could not remove post image: ${error.message}`);
  }
};

const populatePost = async (post) => {
  await post.populate([
    { path: 'user', select: 'name profileImage' },
    { path: 'reactions.user', select: 'name' },
    { path: 'comments.user', select: 'name profileImage' },
  ]);
  return post;
};

const canInteractWithPost = async (post, userId) => {
  if (post.community) {
    return Boolean(await Community.exists({
      _id: post.community,
      'members.user': userId,
    }));
  }
  const author = await User.findById(post.user).select('isPrivate');
  if (!author) return false;
  if (!author.isPrivate || String(author._id) === userId) return true;
  return Boolean(await Follow.exists({
    follower: userId,
    following: author._id,
  }));
};

const postIdFromRequest = (req) => req.params.postId || req.params.id;

const parseTags = (value) => {
  if (!value) return [];
  try {
    const tags = JSON.parse(value);
    return Array.isArray(tags) ? tags.filter((tag) => typeof tag === 'string') : [];
  } catch (error) {
    return [];
  }
};

const extractTags = (caption, value) => {
  const explicitTags = parseTags(value);
  const captionTags = [...caption.matchAll(/#([\p{L}\p{N}_]+)/gu)].map(
    (match) => match[1].toLowerCase(),
  );
  return [...new Set([...explicitTags, ...captionTags])];
};

exports.getPosts = async (req, res) => {
  try {
    const filter = {};
    const communityId = typeof req.query.communityId === 'string'
      ? req.query.communityId.trim()
      : '';
    if (communityId) {
      if (!mongoose.isValidObjectId(communityId)) {
        return res.status(400).json({ message: 'กลุ่มหรือเพจไม่ถูกต้อง' });
      }
      const communityExists = await Community.exists({ _id: communityId });
      if (!communityExists) return res.status(404).json({ message: 'ไม่พบกลุ่มหรือเพจนี้' });
      filter.community = communityId;
    } else {
      filter.community = null;
      const privateUsers = await User.find({ isPrivate: true }).select('_id');
      const followedUsers = await Follow.find({
        follower: req.userId,
        following: { $in: privateUsers.map((user) => user._id) },
      }).select('following');
      const visiblePrivateUserIds = new Set(
        followedUsers.map((follow) => String(follow.following)),
      );
      filter.user = {
        $nin: privateUsers
          .filter((user) =>
            String(user._id) !== req.userId &&
            !visiblePrivateUserIds.has(String(user._id))
          )
          .map((user) => user._id),
      };
    }
    const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const location = typeof req.query.location === 'string' ? req.query.location.trim() : '';
    if (query) {
      const escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const matchingUsers = await User.find({
        name: { $regex: escapedQuery, $options: 'i' },
      }).select('_id');
      const searchTerm = query.replace(/^#/, '');
      filter.$or = [
        { caption: { $regex: escapedQuery, $options: 'i' } },
        { location: { $regex: escapedQuery, $options: 'i' } },
        { tags: { $regex: searchTerm, $options: 'i' } },
        { user: { $in: matchingUsers.map((user) => user._id) } },
      ];
    }
    if (typeof req.query.userId === 'string' && req.query.userId.trim()) {
      const profileUserId = req.query.userId.trim();
      if (!mongoose.isValidObjectId(profileUserId)) {
        return res.status(400).json({ message: 'บัญชีผู้ใช้ไม่ถูกต้อง' });
      }
      const profileUser = await User.findById(profileUserId).select('isPrivate');
      if (!profileUser) return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });
      if (profileUser.isPrivate && profileUserId !== req.userId) {
        const isFollowing = await Follow.exists({
          follower: req.userId,
          following: profileUser._id,
        });
        if (!isFollowing) {
          return res.status(403).json({ message: 'โพสต์จะแสดงหลังจากเจ้าของอนุมัติคำขอติดตาม' });
        }
      }
      filter.user = profileUser._id;
    }
    if (location) filter.location = { $ne: '' };
    const posts = await Post.find(filter)
      .populate('user', 'name profileImage')
      .populate('reactions.user', 'name')
      .populate('comments.user', 'name profileImage')
      .sort({ createdAt: -1 })
      .limit(100);
    if (req.query.sort === 'popular') {
      posts.sort((a, b) =>
        b.reactions.length - a.reactions.length ||
        b.createdAt.getTime() - a.createdAt.getTime()
      );
    }
    const following = await Follow.find({ follower: req.userId }).select('following');
    const followedIds = new Set(following.map((follow) => String(follow.following)));
    const pendingRequests = await FollowRequest.find({
      requester: req.userId,
      recipient: { $in: posts.map((post) => post.user?._id ?? post.user) },
      status: 'pending',
    }).select('recipient');
    const pendingIds = new Set(
      pendingRequests.map((request) => String(request.recipient)),
    );
    res.json(posts.map((post) => {
      const authorId = post.user?._id ?? post.user;
      return {
        ...post.toObject(),
        isFollowedByMe: followedIds.has(String(authorId)),
        followRequestPending: pendingIds.has(String(authorId)),
      };
    }));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.createPost = async (req, res) => {
  try {
    const caption = typeof req.body.caption === 'string' ? req.body.caption.trim() : '';
    if (!caption) {
      if (req.file) await removeUploadedImage(`/uploads/${req.file.filename}`);
      return res.status(400).json({ message: 'กรุณาเขียนข้อความก่อนโพสต์' });
    }

    let communityId = null;
    if (typeof req.body.communityId === 'string' && req.body.communityId.trim()) {
      communityId = req.body.communityId.trim();
      if (!mongoose.isValidObjectId(communityId)) {
        if (req.file) await removeUploadedImage(`/uploads/${req.file.filename}`);
        return res.status(400).json({ message: 'กลุ่มหรือเพจไม่ถูกต้อง' });
      }
      const community = await Community.findById(communityId);
      if (!community) {
        if (req.file) await removeUploadedImage(`/uploads/${req.file.filename}`);
        return res.status(404).json({ message: 'ไม่พบกลุ่มหรือเพจนี้' });
      }
      const isAdmin = community.members.some(
        (member) => String(member.user) === req.userId && member.role === 'admin',
      );
      if (!isAdmin) {
        if (req.file) await removeUploadedImage(`/uploads/${req.file.filename}`);
        return res.status(403).json({ message: 'เฉพาะผู้ดูแลชุมชนเท่านั้นที่โพสต์ได้' });
      }
    }

    const post = await Post.create({
      user: req.userId,
      community: communityId,
      caption,
      imageUrl: req.file ? `/uploads/${req.file.filename}` : '',
      mediaType: req.file?.mimetype.startsWith('video/') ? 'video' : 'image',
      location: typeof req.body.location === 'string' ? req.body.location.trim() : '',
      tags: extractTags(caption, req.body.tags),
    });
    res.status(201).json(await populatePost(post));
  } catch (error) {
    if (req.file) await removeUploadedImage(`/uploads/${req.file.filename}`);
    res.status(500).json({ message: error.message });
  }
};

exports.updatePost = async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ message: 'ไม่พบโพสต์นี้' });
    if (String(post.user) !== req.userId) {
      return res.status(403).json({ message: 'คุณไม่มีสิทธิ์แก้ไขโพสต์นี้' });
    }

    const previousMedia = post.imageUrl;
    if (typeof req.body.caption === 'string') {
      const caption = req.body.caption.trim();
      if (!caption) {
        if (req.file) await removeUploadedImage(`/uploads/${req.file.filename}`);
        return res.status(400).json({ message: 'กรุณาเขียนคำบรรยายโพสต์' });
      }
      post.caption = caption;
    }
    if (typeof req.body.location === 'string') post.location = req.body.location.trim();
    if (typeof req.body.tags === 'string' || typeof req.body.caption === 'string') {
      post.tags = extractTags(post.caption, req.body.tags ?? JSON.stringify(post.tags));
    }
    if (req.body.removeMedia === 'true') {
      post.imageUrl = '';
      post.mediaType = 'image';
    }
    if (req.file) {
      post.imageUrl = `/uploads/${req.file.filename}`;
      post.mediaType = req.file.mimetype.startsWith('video/') ? 'video' : 'image';
    }

    await post.save();
    if (req.file || req.body.removeMedia === 'true') {
      await removeUploadedImage(previousMedia);
    }
    res.json(await populatePost(post));
  } catch (error) {
    if (req.file) await removeUploadedImage(`/uploads/${req.file.filename}`);
    res.status(500).json({ message: error.message });
  }
};

exports.deletePost = async (req, res) => {
  try {
    const post = await Post.findById(req.params.id);
    if (!post) return res.status(404).json({ message: 'ไม่พบโพสต์นี้' });
    if (String(post.user) !== req.userId) {
      return res.status(403).json({ message: 'คุณไม่มีสิทธิ์ลบโพสต์นี้' });
    }

    await post.deleteOne();
    await removeUploadedImage(post.imageUrl);
    res.json({ message: 'ลบโพสต์สำเร็จ' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.setReaction = async (req, res) => {
  try {
    const allowedReactions = [
      'Like',
      'Dislike',
      'Love',
      'Haha',
      'Wow',
      'Sad',
      'Angry',
    ];
    const reactionType = req.body.type;
    if (reactionType !== null && !allowedReactions.includes(reactionType)) {
      return res.status(400).json({ message: 'รูปแบบความรู้สึกไม่ถูกต้อง' });
    }

    const post = await Post.findById(postIdFromRequest(req));
    if (!post) return res.status(404).json({ message: 'ไม่พบโพสต์นี้' });
    if (!(await canInteractWithPost(post, req.userId))) {
      return res.status(403).json({ message: 'กรุณาเข้าร่วมชุมชนก่อนโต้ตอบกับโพสต์' });
    }
    const existingIndex = post.reactions.findIndex((reaction) => String(reaction.user) === req.userId);

    if (existingIndex >= 0) {
      if (reactionType === null) post.reactions.splice(existingIndex, 1);
      else post.reactions[existingIndex].type = reactionType;
    } else if (reactionType !== null) {
      post.reactions.push({ user: req.userId, type: reactionType });
    }

    await post.save();
    res.json(await populatePost(post));
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.reportPost = async (req, res) => {
  const allowedReasons = [
    'Inappropriate content',
    'Spam',
    'Harassment',
    'False information',
    'Other',
  ];
  const reason = req.body.reason;
  if (!allowedReasons.includes(reason)) {
    return res.status(400).json({ message: 'เหตุผลการรายงานไม่ถูกต้อง' });
  }

  try {
    const post = await Post.findById(postIdFromRequest(req));
    if (!post) return res.status(404).json({ message: 'ไม่พบโพสต์นี้' });
    if (!(await canInteractWithPost(post, req.userId))) {
      return res.status(403).json({ message: 'กรุณาเข้าร่วมชุมชนก่อนรายงานโพสต์' });
    }
    if (String(post.user) === req.userId) {
      return res.status(400).json({ message: 'ไม่สามารถรายงานโพสต์ของตนเองได้' });
    }

    await PostReport.create({ post: post._id, user: req.userId, reason });
    res.status(201).json({ message: 'ส่งรายงานโพสต์แล้ว' });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({ message: 'คุณรายงานโพสต์นี้ไปแล้ว' });
    }
    res.status(500).json({ message: error.message });
  }
};

exports.addComment = async (req, res) => {
  try {
    const text = typeof req.body.text === 'string' ? req.body.text.trim() : '';
    if (!text) return res.status(400).json({ message: 'กรุณาเขียนความคิดเห็น' });

    const [post, user] = await Promise.all([
      Post.findById(postIdFromRequest(req)),
      User.findById(req.userId).select('name profileImage'),
    ]);
    if (!post) return res.status(404).json({ message: 'ไม่พบโพสต์นี้' });
    if (!(await canInteractWithPost(post, req.userId))) {
      return res.status(403).json({ message: 'กรุณาเข้าร่วมชุมชนก่อนแสดงความคิดเห็น' });
    }
    if (!user) return res.status(404).json({ message: 'ไม่พบบัญชีผู้ใช้' });

    post.comments.push({ user: user._id, text });
    await post.save();
    res.status(201).json({
      id: post.comments[post.comments.length - 1]._id,
      user: { id: user._id, name: user.name, profileImage: user.profileImage },
      text,
      createdAt: post.comments[post.comments.length - 1].createdAt,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.deleteComment = async (req, res) => {
  try {
    const post = await Post.findById(postIdFromRequest(req));
    if (!post) return res.status(404).json({ message: 'ไม่พบโพสต์นี้' });
    if (!(await canInteractWithPost(post, req.userId))) {
      return res.status(403).json({ message: 'กรุณาเข้าร่วมชุมชนก่อนจัดการความคิดเห็น' });
    }
    const comment = post.comments.id(req.params.commentId);
    if (!comment) return res.status(404).json({ message: 'ไม่พบความคิดเห็นนี้' });
    if (String(comment.user) !== req.userId && String(post.user) !== req.userId) {
      return res.status(403).json({ message: 'คุณไม่มีสิทธิ์ลบความคิดเห็นนี้' });
    }

    comment.deleteOne();
    await post.save();
    res.json({ message: 'ลบความคิดเห็นสำเร็จ' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

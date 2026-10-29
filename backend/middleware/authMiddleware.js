const jwt = require('jsonwebtoken');
const User = require('../models/User');

module.exports = async (req, res, next) => {
  const authorization = req.headers.authorization;
  const token = authorization && authorization.startsWith('Bearer ')
    ? authorization.slice(7)
    : null;

  if (!token) {
    return res.status(401).json({ message: 'กรุณาเข้าสู่ระบบ' });
  }

  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    return res.status(401).json({ message: 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่' });
  }

  try {
    const user = await User.findById(payload.id).select('_id');
    if (!user) {
      return res.status(401).json({ message: 'บัญชีนี้ไม่มีอยู่อีกต่อไป กรุณาเข้าสู่ระบบใหม่' });
    }
    req.userId = String(user._id);
    next();
  } catch (error) {
    res.status(500).json({ message: 'ตรวจสอบบัญชีผู้ใช้ไม่สำเร็จ' });
  }
};

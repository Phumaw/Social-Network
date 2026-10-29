const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const {
  listCommunities,
  getCommunity,
  createCommunity,
  updateCommunity,
  joinCommunity,
  leaveCommunity,
  deleteCommunity,
} = require('../controllers/communityController');

const router = express.Router();

router.use(authMiddleware);
router.get('/', listCommunities);
router.post('/', createCommunity);
router.get('/:id', getCommunity);
router.put('/:id', updateCommunity);
router.post('/:id/join', joinCommunity);
router.post('/:id/leave', leaveCommunity);
router.delete('/:id', deleteCommunity);

module.exports = router;

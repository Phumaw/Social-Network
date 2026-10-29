import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/food_post.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _authService = AuthService();
  final _postService = PostService();
  AppUser? _user;
  String _currentUserId = '';
  List<FoodPost> _posts = [];
  int? _followersCount;
  int? _followingCount;
  bool _isSelf = false;
  bool _isFollowing = false;
  bool _followRequestPending = false;
  bool _canViewContent = false;
  bool _busy = false;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _authService.getPublicProfile(widget.userId);
      final user = profile['user'] as AppUser;
      final canViewContent = profile['canViewPrivateContent'] as bool;
      final results = await Future.wait<dynamic>([
        _authService.refreshUser(),
        canViewContent
            ? _postService.getPosts(userId: widget.userId)
            : Future.value(<FoodPost>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _user = user;
        _currentUserId = (results[0] as AppUser).id;
        _posts = results[1] as List<FoodPost>;
        _isSelf = profile['isSelf'] as bool;
        _isFollowing = profile['isFollowing'] as bool;
        _followRequestPending = profile['followRequestPending'] as bool;
        _canViewContent = canViewContent;
        _followersCount = profile['followersCount'] as int?;
        _followingCount = profile['followingCount'] as int?;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final user = _user;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_isFollowing || _followRequestPending) {
        await _authService.unfollowUser(user.id);
      } else {
        await _authService.followUser(user.id);
      }
      await _load();
    } catch (error) {
      _showMessage('เปลี่ยนสถานะติดตามไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Widget _buildProfile(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: user.bannerImage.isEmpty
              ? Container(color: AppTheme.primaryColor)
              : Image.network(
                  ApiService.resolveImageUrl(user.bannerImage),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: AppTheme.primaryColor),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -30),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppTheme.backgroundColor,
                  child: CircleAvatar(
                    radius: 34,
                    backgroundImage: user.profileImage.isEmpty
                        ? null
                        : NetworkImage(
                            ApiService.resolveImageUrl(user.profileImage),
                          ),
                    child: user.profileImage.isEmpty
                        ? Text(
                            user.name.isEmpty
                                ? '?'
                                : user.name.characters.first,
                          )
                        : null,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!_isSelf)
                          FilledButton.tonalIcon(
                            onPressed: _busy ? null : _toggleFollow,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isFollowing
                                        ? Icons.person_remove_outlined
                                        : _followRequestPending
                                        ? Icons.hourglass_top
                                        : Icons.person_add_alt_1_outlined,
                                  ),
                            label: Text(
                              _isFollowing
                                  ? 'เลิกติดตาม'
                                  : _followRequestPending
                                  ? 'ยกเลิกคำขอ'
                                  : user.isPrivate
                                  ? 'ขอติดตาม'
                                  : 'ติดตาม',
                            ),
                          ),
                      ],
                    ),
                    if (user.username.isNotEmpty)
                      Text(
                        '@${user.username}',
                        style: const TextStyle(color: AppTheme.accentColor),
                      ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(user.bio),
                    ],
                    const SizedBox(height: 10),
                    if (_canViewContent)
                      Text(
                        '${_followersCount ?? 0} ผู้ติดตาม   ${_followingCount ?? 0} กำลังติดตาม',
                        style: const TextStyle(color: AppTheme.mutedTextColor),
                      ),
                    if (user.isPrivate)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 16),
                            SizedBox(width: 5),
                            Text('บัญชีส่วนตัว'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('โหลดโปรไฟล์ไม่สำเร็จ: $_error'),
                  TextButton(
                    onPressed: _load,
                    child: const Text('ลองอีกครั้ง'),
                  ),
                ],
              ),
            )
          : user == null
          ? const Center(child: Text('ไม่พบบัญชีผู้ใช้นี้'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _buildProfile(user),
                  const Divider(height: 1),
                  if (!_canViewContent && user.isPrivate)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 55,
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lock_outline, size: 44),
                          SizedBox(height: 12),
                          Text(
                            'โพสต์และรายชื่อผู้ติดตามจะแสดงเมื่อเจ้าของบัญชีอนุมัติคำขอติดตาม',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else if (_posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 50),
                      child: Center(child: Text('ยังไม่มีโพสต์')),
                    )
                  else
                    ..._posts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: PostCard(
                          post: post,
                          currentUserId: _currentUserId,
                          onChanged: _load,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

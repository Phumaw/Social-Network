import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/food_post.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import 'edit_profile_screen.dart';
import 'follow_requests_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _postService = PostService();
  AppUser? _user;
  List<FoodPost> _posts = [];
  List<AppUser> _followers = [];
  List<AppUser> _following = [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _authService.refreshUser();
      final results = await Future.wait<dynamic>([
        _postService.getPosts(userId: user.id),
        _authService.getFollowStats(),
      ]);
      if (!mounted) return;
      final posts = results[0] as List<FoodPost>;
      final followStats = results[1] as Map<String, List<AppUser>>;
      setState(() {
        _user = user;
        _posts = posts.where((post) => post.userId == user.id).toList();
        _followers = followStats['followers'] ?? [];
        _following = followStats['following'] ?? [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) return;
    final updatedUser = await Navigator.push<AppUser>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: user)),
    );
    if (updatedUser != null && mounted) {
      setState(() => _user = updatedUser);
      await _load();
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบบัญชีถาวร'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'การดำเนินการนี้จะลบบัญชี โพสต์ ความคิดเห็น รีแอ็กชัน '
              'ข้อความแชต และข้อมูลที่เกี่ยวข้องทั้งหมด ไม่สามารถย้อนกลับได้',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'รหัสผ่านปัจจุบัน',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('ลบบัญชีถาวร'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (!mounted || password == null) return;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรหัสผ่านปัจจุบัน')),
      );
      return;
    }

    try {
      await _authService.deleteAccount(password);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ลบบัญชีไม่สำเร็จ: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _showFollowList({
    required String title,
    required List<AppUser> users,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const Center(child: Text('ยังไม่มีรายชื่อ'))
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.profileImage.isNotEmpty
                                  ? NetworkImage(
                                      ApiService.resolveImageUrl(
                                        user.profileImage,
                                      ),
                                    )
                                  : null,
                              child: user.profileImage.isEmpty
                                  ? Text(user.name.isEmpty ? '?' : user.name[0])
                                  : null,
                            ),
                            title: Text(user.name),
                            subtitle: user.username.isEmpty
                                ? null
                                : Text('@${user.username}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('โปรไฟล์'),
        actions: [
          IconButton(
            tooltip: 'คำขอติดตาม',
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const FollowRequestsScreen(),
                ),
              );
              if (mounted) _load();
            },
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : user == null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    height: 158,
                    width: double.infinity,
                    color: AppTheme.primaryColor,
                    child: user.bannerImage.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.hub_rounded,
                              size: 48,
                              color: AppTheme.accentColor,
                            ),
                          )
                        : Image.network(
                            ApiService.resolveImageUrl(user.bannerImage),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.hub_rounded,
                                size: 48,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -42),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: AppTheme.surfaceColor,
                                child: CircleAvatar(
                                  radius: 41,
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.35),
                                  backgroundImage: user.profileImage.isNotEmpty
                                      ? NetworkImage(
                                          ApiService.resolveImageUrl(
                                            user.profileImage,
                                          ),
                                        )
                                      : null,
                                  child: user.profileImage.isEmpty
                                      ? Text(
                                          user.name.isEmpty
                                              ? '?'
                                              : user.name[0],
                                          style: const TextStyle(fontSize: 28),
                                        )
                                      : null,
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: _editProfile,
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: const Text('แก้ไขโปรไฟล์'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                  foregroundColor: AppTheme.textDark,
                                  side: const BorderSide(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user.username.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username}',
                              style: const TextStyle(
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (user.bio.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              user.bio,
                              style: const TextStyle(
                                color: AppTheme.mutedTextColor,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _followCountButton(
                                label: 'ผู้ติดตาม',
                                count: _followers.length,
                                onTap: () => _showFollowList(
                                  title: 'ผู้ติดตาม',
                                  users: _followers,
                                ),
                              ),
                              const SizedBox(width: 24),
                              _followCountButton(
                                label: 'กำลังติดตาม',
                                count: _following.length,
                                onTap: () => _showFollowList(
                                  title: 'กำลังติดตาม',
                                  users: _following,
                                ),
                              ),
                            ],
                          ),
                          if (user.address.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 17,
                                  color: AppTheme.mutedTextColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(child: Text(user.address)),
                              ],
                            ),
                          ],
                          if (user.email.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  size: 17,
                                  color: AppTheme.mutedTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    color: AppTheme.mutedTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            '${_posts.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                            ),
                          ),
                          const Text(
                            'โพสต์',
                            style: TextStyle(color: AppTheme.mutedTextColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  if (_posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 42,
                        horizontal: 24,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 42,
                            color: AppTheme.mutedTextColor,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'คุณยังไม่มีโพสต์',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 5,
                            mainAxisSpacing: 5,
                          ),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: post.imageUrl.isEmpty
                              ? const ColoredBox(
                                  color: AppTheme.raisedSurfaceColor,
                                  child: Center(
                                    child: Icon(Icons.text_snippet_outlined),
                                  ),
                                )
                              : post.mediaType == 'video'
                              ? const ColoredBox(
                                  color: AppTheme.raisedSurfaceColor,
                                  child: Center(
                                    child: Icon(Icons.play_circle_outline),
                                  ),
                                )
                              : Image.network(
                                  ApiService.resolveImageUrl(post.imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: AppTheme.raisedSurfaceColor,
                                    child: const Icon(
                                      Icons.image_not_supported,
                                    ),
                                  ),
                                ),
                        );
                      },
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.red.shade700,
                    ),
                    title: Text(
                      'ลบบัญชีถาวร',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    subtitle: const Text('ลบบัญชีและข้อมูลทั้งหมดออกจากระบบ'),
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 8),
          Text(
            _error == null
                ? 'ไม่พบข้อมูลผู้ใช้'
                : 'โหลดโปรไฟล์ไม่สำเร็จ: $_error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    ),
  );

  Widget _followCountButton({
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppTheme.mutedTextColor)),
          ],
        ),
      ),
    );
  }
}

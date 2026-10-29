import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/food_post.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../group/community_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _postService = PostService();
  AppUser? _user;
  List<FoodPost> _posts = [];
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
      final results = await Future.wait<dynamic>([
        _postService.getPosts(),
        _authService.refreshUser(),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<FoodPost>;
        _user = results[1] as AppUser;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              const Text(
                'ฟีดของคุณ',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'เรื่องราวและบทสนทนาจากชุมชนของคุณ',
                style: TextStyle(color: AppTheme.mutedTextColor),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildError()
              else if (_posts.isEmpty)
                _buildEmpty()
              else
                ..._posts.map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: PostCard(
                      key: ValueKey(post.id),
                      post: post,
                      currentUserId: _user?.id ?? '',
                      onChanged: _load,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = _user;
    return Row(
      children: [
        const SocialNetworkMark(size: 40),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Social Network',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ),
        IconButton(
          tooltip: 'กลุ่มและชุมชน',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CommunityListScreen(),
            ),
          ),
          icon: const Icon(Icons.groups_outlined),
        ),
        if (user != null)
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: user.profileImage.isNotEmpty
                ? NetworkImage(ApiService.resolveImageUrl(user.profileImage))
                : null,
            child: user.profileImage.isEmpty
                ? Text(
                    user.name.isEmpty ? '?' : user.name.characters.first,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
      ],
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: AppTheme.mutedTextColor,
          ),
          const SizedBox(height: 12),
          const Text(
            'โหลดฟีดไม่สำเร็จ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.mutedTextColor),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.hub_rounded, size: 48, color: AppTheme.accentColor),
          SizedBox(height: 12),
          Text(
            'ยังไม่มีโพสต์ในฟีด',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            'แบ่งปันเรื่องราวแรกของคุณกับชุมชนได้เลย',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedTextColor),
          ),
        ],
      ),
    );
  }
}

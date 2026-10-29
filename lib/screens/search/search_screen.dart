import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/food_post.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';
import '../group/community_list_screen.dart';
import '../profile/public_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  final AuthService? authService;
  final PostService? postService;

  const SearchScreen({super.key, this.authService, this.postService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  late final _postService = widget.postService ?? PostService();
  late final _authService = widget.authService ?? AuthService();
  List<FoodPost> _posts = [];
  List<AppUser> _users = [];
  AppUser? _user;
  Timer? _searchDebounce;
  String _sort = 'recent';
  String _searchMode = 'posts';
  bool _withLocation = false;
  bool _loading = true;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _queryController.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    _requestId++;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    final query = _queryController.text.trim();
    final searchMode = _searchMode;
    final sort = _sort;
    final withLocation = _withLocation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        searchMode == 'users'
            ? _authService.searchUsers(query)
            : _postService.getPosts(
                query: searchMode == 'tags' && query.isNotEmpty
                    ? (query.startsWith('#') ? query : '#$query')
                    : query,
                sort: sort,
                withLocation: withLocation,
              ),
        _user == null ? _authService.refreshUser() : Future.value(null),
      ]);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        if (searchMode == 'users') {
          _users = results[0] as List<AppUser>;
        } else {
          _posts = results[0] as List<FoodPost>;
        }
        _user ??= results[1] as AppUser?;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _queryController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ค้นหาและค้นพบ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'กลุ่มและชุมชน',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CommunityListScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Semantics(
              container: true,
              label: _searchMode == 'users'
                  ? 'ค้นหาผู้ใช้'
                  : _searchMode == 'tags'
                  ? 'ค้นหาแฮชแท็ก'
                  : 'ค้นหาโพสต์หรือแฮชแท็ก',
              textField: true,
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  labelText: _searchMode == 'users'
                      ? 'ค้นหาผู้ใช้'
                      : _searchMode == 'tags'
                      ? 'ค้นหาแฮชแท็ก'
                      : 'ค้นหาโพสต์หรือแฮชแท็ก',
                  hintText: _searchMode == 'users'
                      ? 'ค้นหาชื่อหรือ @username'
                      : _searchMode == 'tags'
                      ? 'ค้นหาแฮชแท็ก เช่น อาหาร'
                      : 'ค้นหาโพสต์หรือ #แฮชแท็ก',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.textDark,
                  ),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'ล้างการค้นหา',
                          onPressed: () => _queryController.clear(),
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'posts', label: Text('โพสต์')),
                ButtonSegment(value: 'users', label: Text('ผู้ใช้')),
                ButtonSegment(value: 'tags', label: Text('#แท็ก')),
              ],
              selected: {_searchMode},
              onSelectionChanged: (selection) {
                setState(() => _searchMode = selection.first);
                _load();
              },
            ),
          ),
          if (_searchMode != 'users')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('ล่าสุด'),
                    selected: _sort == 'recent',
                    onSelected: (_) {
                      setState(() => _sort = 'recent');
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('ยอดนิยม'),
                    selected: _sort == 'popular',
                    onSelected: (_) {
                      setState(() => _sort = 'popular');
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('มีสถานที่'),
                    selected: _withLocation,
                    onSelected: (selected) {
                      setState(() => _withLocation = selected);
                      _load();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(onRefresh: _load, child: _buildResults()),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text('ค้นหาไม่สำเร็จ: $_error', textAlign: TextAlign.center),
          ),
          Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('ลองอีกครั้ง'),
            ),
          ),
        ],
      );
    }
    if (_searchMode == 'users') {
      if (_users.isEmpty) {
        return ListView(
          children: const [
            SizedBox(height: 140),
            Icon(
              Icons.person_search_outlined,
              size: 48,
              color: AppTheme.mutedTextColor,
            ),
            SizedBox(height: 12),
            Center(child: Text('ไม่พบผู้ใช้ที่ตรงกับการค้นหา')),
          ],
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _users.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user.profileImage.isEmpty
                  ? null
                  : NetworkImage(ApiService.resolveImageUrl(user.profileImage)),
              child: user.profileImage.isEmpty
                  ? Text(user.name.isEmpty ? '?' : user.name.characters.first)
                  : null,
            ),
            title: Text(user.name),
            subtitle: Text(
              [
                if (user.username.isNotEmpty) '@${user.username}',
                if (user.bio.isNotEmpty) user.bio,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: user.isPrivate
                ? const Tooltip(
                    message: 'บัญชีส่วนตัว',
                    child: Icon(Icons.lock_outline, size: 18),
                  )
                : null,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PublicProfileScreen(userId: user.id),
              ),
            ),
          );
        },
      );
    }
    if (_posts.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: 140),
          Icon(Icons.search_off, size: 48, color: AppTheme.mutedTextColor),
          SizedBox(height: 12),
          Center(
            child: Text(
              _searchMode == 'tags'
                  ? 'ไม่พบโพสต์ที่มีแฮชแท็กนี้'
                  : 'ไม่พบโพสต์ที่ตรงกับการค้นหา',
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _posts.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: PostCard(
          key: ValueKey(_posts[index].id),
          post: _posts[index],
          currentUserId: _user?.id ?? '',
          onChanged: _load,
        ),
      ),
    );
  }
}

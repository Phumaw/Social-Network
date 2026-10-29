import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/community.dart';
import '../../models/food_post.dart';
import '../../screens/post/create_post_screen.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/post_card.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final _communityService = CommunityService();
  final _postService = PostService();
  final _authService = AuthService();
  Community? _community;
  AppUser? _user;
  List<FoodPost> _posts = [];
  Object? _error;
  bool _loading = true;
  bool _updatingMembership = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        _communityService.getCommunity(widget.communityId),
        _postService.getPosts(communityId: widget.communityId),
        _user == null ? _authService.refreshUser() : Future.value(null),
      ]);
      if (!mounted) return;
      setState(() {
        _community = results[0] as Community;
        _posts = results[1] as List<FoodPost>;
        _user ??= results[2] as AppUser?;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggleMembership() async {
    final community = _community;
    if (community == null || _updatingMembership) return;
    if (community.isMember) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ออกจากชุมชน'),
          content: Text(
            'ต้องการออกจาก${community.isPage ? 'เพจ' : 'กลุ่ม'} "${community.name}" หรือไม่?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ออกจากชุมชน'),
            ),
          ],
        ),
      );
      if (shouldLeave != true || !mounted) return;
    }

    setState(() => _updatingMembership = true);
    try {
      if (community.isMember) {
        await _communityService.leaveCommunity(community.id);
        _showMessage('ออกจากชุมชนแล้ว');
      } else {
        await _communityService.joinCommunity(community.id);
        _showMessage('เข้าร่วมชุมชนแล้ว');
      }
      await _load();
    } catch (error) {
      _showMessage('เปลี่ยนสถานะสมาชิกไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _updatingMembership = false);
    }
  }

  Future<void> _editCommunity() async {
    final community = _community;
    if (community == null) return;
    final nameController = TextEditingController(text: community.name);
    final descriptionController = TextEditingController(
      text: community.description,
    );
    var type = community.type;
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('แก้ไขข้อมูลชุมชน'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'ชื่อ'),
                ),
                TextField(
                  controller: descriptionController,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'คำอธิบาย'),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'group', label: Text('กลุ่ม')),
                    ButtonSegment(value: 'page', label: Text('เพจ')),
                  ],
                  selected: {type},
                  onSelectionChanged: (selection) =>
                      setDialogState(() => type = selection.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim(),
                'type': type,
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (data == null || !mounted) return;
    try {
      await _communityService.updateCommunity(
        community.id,
        name: data['name']!,
        description: data['description']!,
        type: data['type']!,
      );
      await _load();
      _showMessage('บันทึกข้อมูลชุมชนแล้ว');
    } catch (error) {
      _showMessage('แก้ไขชุมชนไม่สำเร็จ: $error', isError: true);
    }
  }

  Future<void> _deleteCommunity() async {
    final community = _community;
    if (community == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบชุมชน'),
        content: Text(
          'ลบ${community.isPage ? 'เพจ' : 'กลุ่ม'} "${community.name}" และโพสต์ทั้งหมดภายในหรือไม่? การดำเนินการนี้ย้อนกลับไม่ได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบชุมชน'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _communityService.deleteCommunity(community.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showMessage('ลบชุมชนไม่สำเร็จ: $error', isError: true);
    }
  }

  Future<void> _createCommunityPost() async {
    final community = _community;
    if (community == null || !community.isAdmin) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            CreatePostScreen(communityId: community.id, onPosted: _load),
      ),
    );
    if (mounted) _load();
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

  Widget _buildHeader(Community community) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: AppTheme.primaryColor,
                child: Icon(
                  community.isPage
                      ? Icons.article_outlined
                      : Icons.groups_outlined,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${community.isPage ? 'เพจ' : 'กลุ่ม'} · ${community.memberCount} สมาชิก · สร้างโดย ${community.creatorName}',
                      style: const TextStyle(
                        color: AppTheme.mutedTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (community.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(community.description),
          ],
          const SizedBox(height: 14),
          if (!community.isAdmin)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _updatingMembership ? null : _toggleMembership,
                  icon: _updatingMembership
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          community.isMember
                              ? Icons.logout
                              : Icons.group_add_outlined,
                        ),
                  label: Text(community.isMember ? 'ออกจากชุมชน' : 'เข้าร่วม'),
                ),
                if (!community.isMember)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'เข้าร่วมเพื่อแสดงความคิดเห็นและแสดงความรู้สึก',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.mutedTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            )
          else
            const Chip(
              avatar: Icon(Icons.admin_panel_settings_outlined, size: 18),
              label: Text('ผู้ดูแลชุมชน'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final community = _community;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(community?.name ?? 'ชุมชน'),
        actions: [
          if (community?.isAdmin == true)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editCommunity();
                if (value == 'delete') _deleteCommunity();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('แก้ไขข้อมูล')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('ลบชุมชน', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: community?.isAdmin == true
          ? FloatingActionButton.extended(
              onPressed: _createCommunityPost,
              icon: const Icon(Icons.add),
              label: const Text('โพสต์'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('โหลดชุมชนไม่สำเร็จ: $_error'),
                  TextButton(
                    onPressed: _load,
                    child: const Text('ลองอีกครั้ง'),
                  ),
                ],
              ),
            )
          : community == null
          ? const Center(child: Text('ไม่พบชุมชนนี้'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  _buildHeader(community),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'ฟีดชุมชน',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_posts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 48,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.forum_outlined,
                            size: 42,
                            color: AppTheme.mutedTextColor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            community.isAdmin
                                ? 'ยังไม่มีโพสต์ เริ่มแบ่งปันเรื่องราวได้เลย'
                                : 'ยังไม่มีโพสต์ในชุมชนนี้',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ..._posts.map(
                      (post) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: PostCard(
                          key: ValueKey(post.id),
                          post: post,
                          currentUserId: _user?.id ?? '',
                          onChanged: _load,
                          interactionsEnabled: community.isMember,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

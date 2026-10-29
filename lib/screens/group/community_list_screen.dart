import 'package:flutter/material.dart';

import '../../models/community.dart';
import '../../services/community_service.dart';
import '../../theme/app_theme.dart';
import 'community_detail_screen.dart';

class CommunityListScreen extends StatefulWidget {
  const CommunityListScreen({super.key});

  @override
  State<CommunityListScreen> createState() => _CommunityListScreenState();
}

class _CommunityListScreenState extends State<CommunityListScreen> {
  final _service = CommunityService();
  final _searchController = TextEditingController();
  List<Community> _communities = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final communities = await _service.getCommunities(
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _communities = communities;
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

  Future<void> _createCommunity() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    var type = 'group';
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('สร้างกลุ่มหรือเพจ'),
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
                    ButtonSegment(
                      value: 'group',
                      label: Text('กลุ่ม'),
                      icon: Icon(Icons.groups_outlined),
                    ),
                    ButtonSegment(
                      value: 'page',
                      label: Text('เพจ'),
                      icon: Icon(Icons.article_outlined),
                    ),
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
              child: const Text('สร้าง'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (data == null || !mounted) return;
    if (data['name']!.isEmpty) {
      _showMessage('กรุณาระบุชื่อกลุ่มหรือเพจ', isError: true);
      return;
    }
    try {
      final community = await _service.createCommunity(
        name: data['name']!,
        description: data['description']!,
        type: data['type']!,
      );
      if (!mounted) return;
      await _load();
      await _openCommunity(community);
    } catch (error) {
      if (mounted) _showMessage('สร้างชุมชนไม่สำเร็จ: $error', isError: true);
    }
  }

  Future<void> _openCommunity(Community community) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CommunityDetailScreen(communityId: community.id),
      ),
    );
    if (mounted) _load();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('กลุ่มและเพจ'),
        actions: [
          IconButton(
            tooltip: 'สร้างกลุ่มหรือเพจ',
            onPressed: _createCommunity,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'ค้นหากลุ่มหรือเพจ',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'ค้นหา',
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text('โหลดชุมชนไม่สำเร็จ: $_error')),
                        Center(
                          child: TextButton(
                            onPressed: _load,
                            child: const Text('ลองอีกครั้ง'),
                          ),
                        ),
                      ],
                    )
                  : _communities.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Icon(
                          Icons.groups_outlined,
                          size: 52,
                          color: AppTheme.mutedTextColor,
                        ),
                        SizedBox(height: 12),
                        Center(child: Text('ยังไม่มีกลุ่มหรือเพจ')),
                        Center(child: Text('สร้างชุมชนแรกของคุณได้เลย')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _communities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final community = _communities[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: AppTheme.primaryColor,
                              child: Icon(
                                community.isPage
                                    ? Icons.article_outlined
                                    : Icons.groups_outlined,
                              ),
                            ),
                            title: Text(
                              community.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                [
                                  community.isPage ? 'เพจ' : 'กลุ่ม',
                                  '${community.memberCount} สมาชิก',
                                  if (community.isMember) 'เข้าร่วมแล้ว',
                                  if (community.description.isNotEmpty)
                                    community.description,
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openCommunity(community),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

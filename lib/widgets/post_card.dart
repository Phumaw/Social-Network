import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/food_post.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

class PostCard extends StatefulWidget {
  final FoodPost post;
  final String currentUserId;
  final Future<void> Function() onChanged;
  final PostService? postService;
  final bool interactionsEnabled;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onChanged,
    this.interactionsEnabled = true,
    this.postService,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late final _postService = widget.postService ?? PostService();
  bool _busy = false;
  bool _reporting = false;
  late bool _following = widget.post.isFollowedByMe;
  late bool _followRequestPending = widget.post.followRequestPending;

  FoodPost get post => widget.post;
  String? get _myReaction => post.reactionBy(widget.currentUserId);
  bool get _isMyPost => post.userId == widget.currentUserId;

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isFollowedByMe != widget.post.isFollowedByMe) {
      _following = widget.post.isFollowedByMe;
    }
    if (oldWidget.post.followRequestPending !=
        widget.post.followRequestPending) {
      _followRequestPending = widget.post.followRequestPending;
    }
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = _following || _followRequestPending
          ? await _postService.unfollowUser(post.userId)
          : await _postService.followUser(post.userId);
      if (!mounted) return;
      setState(() {
        _following = result['following'] == true;
        _followRequestPending = result['requestPending'] == true;
      });
      await widget.onChanged();
    } catch (error) {
      _showMessage('ปรับสถานะติดตามไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showImageViewer(String imageUrl, String heroTag) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Hero(
                    tag: heroTag,
                    child: Image.network(
                      ApiService.resolveImageUrl(imageUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'ปิดรูปภาพ',
                  onPressed: () => Navigator.pop(context),
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _react(String? type) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _postService.setReaction(post.id, type);
      await widget.onChanged();
    } catch (error) {
      _showMessage('บันทึกความรู้สึกไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPost() async {
    final captionController = TextEditingController(text: post.caption);
    final locationController = TextEditingController(text: post.location);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขโพสต์'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: captionController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'รีวิว / คำบรรยาย'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'สถานที่'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (shouldSave == true && mounted) {
      try {
        await _postService.updatePost(
          id: post.id,
          caption: captionController.text.trim(),
          location: locationController.text.trim(),
        );
        await widget.onChanged();
        _showMessage('แก้ไขโพสต์แล้ว');
      } catch (error) {
        _showMessage('แก้ไขโพสต์ไม่สำเร็จ: $error', isError: true);
      }
    }
    captionController.dispose();
    locationController.dispose();
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบโพสต์'),
        content: const Text(
          'ต้องการลบโพสต์นี้หรือไม่ การลบไม่สามารถเรียกคืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบโพสต์'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _postService.deletePost(post.id);
      await widget.onChanged();
    } catch (error) {
      _showMessage('ลบโพสต์ไม่สำเร็จ: $error', isError: true);
    }
  }

  Future<void> _reportPost() async {
    if (_reporting) return;
    const reasons = <String, String>{
      'Inappropriate content': 'เนื้อหาไม่เหมาะสม',
      'Spam': 'สแปม',
      'Harassment': 'การคุกคาม',
      'False information': 'ข้อมูลเท็จ',
      'Other': 'อื่นๆ',
    };
    var selectedReason = reasons.keys.first;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('รายงานโพสต์'),
          content: RadioGroup<String>(
            groupValue: selectedReason,
            onChanged: (value) {
              if (value != null) {
                setDialogState(() => selectedReason = value);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons.entries
                  .map(
                    (entry) => RadioListTile<String>(
                      value: entry.key,
                      title: Text(entry.value),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedReason),
              child: const Text('ส่งรายงาน'),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    setState(() => _reporting = true);
    try {
      await _postService.reportPost(post.id, reason);
      _showMessage('ส่งรายงานโพสต์แล้ว');
    } catch (error) {
      _showMessage('รายงานโพสต์ไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  Future<void> _showComments() async {
    final controller = TextEditingController();
    final comments = [...post.comments];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  Text(
                    'ความคิดเห็น (${comments.length})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(
                            child: Text(
                              'ยังไม่มีความคิดเห็น เริ่มบทสนทนาได้เลย',
                            ),
                          )
                        : ListView.builder(
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final canDelete =
                                  comment.userId == widget.currentUserId ||
                                  _isMyPost;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.4),
                                  child: Text(
                                    comment.userName.isEmpty
                                        ? '?'
                                        : comment.userName[0],
                                  ),
                                ),
                                title: Text(
                                  comment.userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(comment.text),
                                trailing: canDelete
                                    ? IconButton(
                                        tooltip: 'ลบความคิดเห็น',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          try {
                                            await _postService.deleteComment(
                                              post.id,
                                              comment.id,
                                            );
                                            setSheetState(
                                              () => comments.removeAt(index),
                                            );
                                            await widget.onChanged();
                                          } catch (error) {
                                            _showMessage(
                                              'ลบความคิดเห็นไม่สำเร็จ: $error',
                                              isError: true,
                                            );
                                          }
                                        },
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) =>
                              _sendComment(controller, comments, setSheetState),
                          decoration: const InputDecoration(
                            hintText: 'เขียนความคิดเห็น...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () =>
                            _sendComment(controller, comments, setSheetState),
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _sendComment(
    TextEditingController controller,
    List<PostComment> comments,
    StateSetter setSheetState,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    try {
      final response =
          await ApiService.post('/posts/${post.id}/comments', {'text': text})
              as Map<String, dynamic>;
      setSheetState(() {
        comments.add(PostComment.fromJson(response));
        controller.clear();
      });
      await widget.onChanged();
    } catch (error) {
      _showMessage('ส่งความคิดเห็นไม่สำเร็จ: $error', isError: true);
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

  @override
  Widget build(BuildContext context) {
    final reaction = _myReaction;
    final reactionCounts = <String, int>{};
    for (final item in post.reactions) {
      reactionCounts.update(item.type, (count) => count + 1, ifAbsent: () => 1);
    }
    final visibleReactions = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
            child: Row(
              children: [
                GestureDetector(
                  key: post.userImage.isEmpty
                      ? null
                      : const Key('post-author-avatar'),
                  onTap: post.userImage.isEmpty
                      ? null
                      : () => _showImageViewer(
                          post.userImage,
                          'post-avatar-${post.id}',
                        ),
                  child: Hero(
                    tag: 'post-avatar-${post.id}',
                    child: CircleAvatar(
                      radius: 21,
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.4,
                      ),
                      child: post.userImage.isEmpty
                          ? Text(post.userName.isEmpty ? '?' : post.userName[0])
                          : ClipOval(
                              child: Image.network(
                                ApiService.resolveImageUrl(post.userImage),
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    post.userName.isEmpty
                                        ? '?'
                                        : post.userName[0],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (post.location.isNotEmpty)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppTheme.mutedTextColor,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                post.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mutedTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isMyPost)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editPost();
                      if (value == 'delete') _deletePost();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('แก้ไขโพสต์'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'ลบโพสต์',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                if (!_isMyPost && widget.interactionsEnabled)
                  IconButton(
                    tooltip: _following
                        ? 'เลิกติดตาม'
                        : _followRequestPending
                        ? 'ยกเลิกคำขอติดตาม'
                        : 'ติดตามผู้โพสต์',
                    onPressed: _busy ? null : _toggleFollow,
                    icon: Icon(
                      _following
                          ? Icons.person_remove_outlined
                          : _followRequestPending
                          ? Icons.hourglass_top
                          : Icons.person_add_alt_1_outlined,
                    ),
                  ),
                if (!_isMyPost && widget.interactionsEnabled)
                  IconButton(
                    tooltip: 'รายงานโพสต์',
                    onPressed: _reporting ? null : _reportPost,
                    icon: _reporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flag_outlined),
                  ),
              ],
            ),
          ),
          if (post.imageUrl.isNotEmpty)
            post.mediaType == 'video'
                ? PostVideoPlayer(
                    key: Key('post-video-${post.id}'),
                    videoUrl: ApiService.resolveImageUrl(post.imageUrl),
                  )
                : GestureDetector(
                    key: const Key('post-image'),
                    onTap: () => _showImageViewer(
                      post.imageUrl,
                      'post-image-${post.id}',
                    ),
                    child: Hero(
                      tag: 'post-image-${post.id}',
                      child: AspectRatio(
                        aspectRatio: 1.15,
                        child: Image.network(
                          ApiService.resolveImageUrl(post.imageUrl),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: AppTheme.raisedSurfaceColor,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 42,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              post.caption,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                if (visibleReactions.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: visibleReactions.take(3).map((entry) {
                        return Semantics(
                          label:
                              '${_reactionLabel(entry.key)} ${entry.value} คน',
                          child: Text(
                            '${_reactionEmoji(entry.key)} ${entry.value}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  '${post.comments.length} ความคิดเห็น',
                  style: const TextStyle(
                    color: AppTheme.mutedTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12),
          if (widget.interactionsEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  _quickReactionButton('Like', '👍', reaction),
                  _quickReactionButton('Dislike', '👎', reaction),
                  _quickReactionButton('Love', '❤️', reaction),
                  IconButton(
                    tooltip: 'แสดงอารมณ์เพิ่มเติม',
                    onPressed: _busy ? null : _chooseReaction,
                    icon: const Icon(Icons.add_reaction_outlined),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'แสดงความคิดเห็น',
                    onPressed: _showComments,
                    icon: const Icon(Icons.mode_comment_outlined),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _chooseReaction() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _reactionChoice(context, 'Like', '👍', 'ถูกใจ'),
              _reactionChoice(context, 'Dislike', '👎', 'ไม่ถูกใจ'),
              _reactionChoice(context, 'Love', '❤️', 'รักเลย'),
              _reactionChoice(context, 'Haha', '😆', 'ฮ่าๆ'),
              _reactionChoice(context, 'Wow', '😮', 'ว้าว'),
              _reactionChoice(context, 'Sad', '😢', 'เศร้า'),
              _reactionChoice(context, 'Angry', '😡', 'โกรธ'),
              if (_myReaction != null)
                _reactionChoice(context, '__remove__', '✖️', 'ยกเลิก'),
            ],
          ),
        ),
      ),
    );
    if (selected != null)
      await _react(selected == '__remove__' ? null : selected);
  }

  Widget _quickReactionButton(
    String type,
    String emoji,
    String? selectedReaction,
  ) {
    final isSelected = selectedReaction == type;
    return TextButton(
      key: Key('reaction-$type'),
      onPressed: _busy ? null : () => _react(isSelected ? null : type),
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? AppTheme.accentColor : AppTheme.textDark,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Semantics(
        label: _reactionLabel(type),
        selected: isSelected,
        child: ExcludeSemantics(
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  Widget _reactionChoice(
    BuildContext context,
    String value,
    String emoji,
    String label,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 27)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _reactionEmoji(String? value) {
    switch (value) {
      case 'Dislike':
        return '👎';
      case 'Love':
        return '❤️';
      case 'Haha':
        return '😆';
      case 'Wow':
        return '😮';
      case 'Sad':
        return '😢';
      case 'Angry':
        return '😡';
      default:
        return '👍';
    }
  }

  String _reactionLabel(String? value) {
    switch (value) {
      case 'Dislike':
        return 'ไม่ถูกใจ';
      case 'Like':
        return 'ถูกใจ';
      case 'Love':
        return 'รักเลย';
      case 'Haha':
        return 'ฮ่าๆ';
      case 'Wow':
        return 'ว้าว';
      case 'Sad':
        return 'เศร้า';
      case 'Angry':
        return 'โกรธ';
      default:
        return 'แสดงความรู้สึก';
    }
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'เวลาไม่ระบุ';
    final difference = DateTime.now().difference(date.toLocal());
    if (difference.inMinutes < 1) return 'เมื่อสักครู่';
    if (difference.inHours < 1) return '${difference.inMinutes} นาทีที่แล้ว';
    if (difference.inDays < 1) return '${difference.inHours} ชั่วโมงที่แล้ว';
    if (difference.inDays < 7) return '${difference.inDays} วันที่แล้ว';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const PostVideoPlayer({super.key, required this.videoUrl});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final VideoPlayerController _controller;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object error) {
            if (mounted) setState(() => _initializationError = error);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return const SizedBox(
        height: 220,
        child: Center(child: Icon(Icons.movie_creation_outlined, size: 42)),
      );
    }
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          IconButton.filled(
            tooltip: _controller.value.isPlaying ? 'หยุดวิดีโอ' : 'เล่นวิดีโอ',
            onPressed: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            },
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

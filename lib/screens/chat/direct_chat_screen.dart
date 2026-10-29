import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';

class DirectChatScreen extends StatefulWidget {
  final AppUser user;

  const DirectChatScreen({super.key, required this.user});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _chatService = ChatService();
  final _authService = AuthService();
  final _picker = ImagePicker();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  String? _currentUserId;
  XFile? _media;
  String? _mediaType;
  Uint8List? _mediaBytes;
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(),
    );
  }

  Future<void> _loadMessages() async {
    try {
      final results = await Future.wait<dynamic>([
        _chatService.getMessages(widget.user.id),
        _currentUserId == null
            ? _authService.refreshUser()
            : Future.value(null),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = results[0] as List<ChatMessage>;
        _currentUserId ??= (results[1] as AppUser?)?.id;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error ??= error;
      });
    }
  }

  Future<void> _chooseMedia() async {
    try {
      final mediaType = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('เลือกรูปภาพ'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('เลือกวิดีโอสั้น (ไม่เกิน 60 วินาที)'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
            ],
          ),
        ),
      );
      if (mediaType == null) return;
      final media = mediaType == 'video'
          ? await _picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 60),
            )
          : await _picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 1800,
            );
      if (media == null) return;
      final bytes = mediaType == 'image' ? await media.readAsBytes() : null;
      if (!mounted) return;
      setState(() {
        _media = media;
        _mediaType = mediaType;
        _mediaBytes = bytes;
      });
    } catch (error) {
      if (mounted) _showMessage('เลือกสื่อไม่สำเร็จ: $error', isError: true);
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final media = _media;
    final mediaType = _mediaType;
    if (_sending || (text.isEmpty && media == null)) return;

    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(
        userId: widget.user.id,
        text: text,
        media: media,
        mediaType: mediaType ?? '',
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _media = null;
        _mediaType = null;
        _mediaBytes = null;
      });
      await _loadMessages();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      if (mounted) _showMessage('ส่งข้อความไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                widget.user.name.isEmpty
                    ? '?'
                    : widget.user.name.characters.first,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.user.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessages()),
            if (_media != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Stack(
                  children: [
                    if (_mediaType == 'video')
                      Container(
                        width: 140,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_file_outlined, size: 32),
                            Text('วิดีโอที่เลือก'),
                          ],
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _mediaBytes!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton.filledTonal(
                        onPressed: () => setState(() {
                          _media = null;
                          _mediaType = null;
                          _mediaBytes = null;
                        }),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'แนบรูปภาพหรือวิดีโอ',
                    onPressed: _sending ? null : _chooseMedia,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('โหลดข้อความไม่สำเร็จ: $_error', textAlign: TextAlign.center),
            TextButton(
              onPressed: _loadMessages,
              child: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('เริ่มต้นบทสนทนาได้เลย'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = message.senderId == _currentUserId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.primaryColor : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imageUrl.isNotEmpty)
                  if (message.mediaType == 'video')
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _ChatVideoPlayer(
                        videoUrl: ApiService.resolveImageUrl(message.imageUrl),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        ApiService.resolveImageUrl(message.imageUrl),
                        width: 210,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 210,
                          height: 100,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                if (message.text.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top: message.imageUrl.isNotEmpty ? 6 : 0,
                    ),
                    child: Text(message.text),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _ChatVideoPlayer({required this.videoUrl});

  @override
  State<_ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<_ChatVideoPlayer> {
  late final VideoPlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            if (mounted) setState(() {});
          })
          .catchError((Object error) {
            if (mounted) setState(() => _error = error);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const SizedBox(
        width: 210,
        height: 120,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        width: 210,
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      width: 210,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            IconButton.filled(
              tooltip: _controller.value.isPlaying
                  ? 'หยุดวิดีโอ'
                  : 'เล่นวิดีโอ',
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

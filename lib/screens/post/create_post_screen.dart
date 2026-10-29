import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/post_service.dart';
import '../../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  final VoidCallback onPosted;
  final String? communityId;
  final PostService? postService;
  final Future<XFile?> Function(ImageSource source)? pickImage;
  final Future<XFile?> Function()? pickVideo;

  const CreatePostScreen({
    super.key,
    required this.onPosted,
    this.communityId,
    this.postService,
    this.pickImage,
    this.pickVideo,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();
  late final _postService = widget.postService ?? PostService();
  XFile? _media;
  Uint8List? _imageBytes;
  String? _mediaType;
  bool _isSaving = false;
  bool _isChoosingImageSource = false;
  bool _isPickingImage = false;

  Future<void> _chooseMediaSource() async {
    if (_isSaving || _isChoosingImageSource || _isPickingImage) return;
    setState(() => _isChoosingImageSource = true);
    try {
      final source = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกรูปจากอัลบั้ม'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('เลือกวิดีโอสั้น (ไม่เกิน 60 วินาที)'),
                onTap: () => Navigator.pop(context, 'video'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || source == null) return;

      setState(() {
        _isChoosingImageSource = false;
        _isPickingImage = true;
      });
      final mediaType = source == 'video' ? 'video' : 'image';
      final media = switch (source) {
        'video' =>
          widget.pickVideo == null
              ? await _picker.pickVideo(
                  source: ImageSource.gallery,
                  maxDuration: const Duration(seconds: 60),
                )
              : await widget.pickVideo!(),
        'camera' =>
          widget.pickImage == null
              ? await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                  maxWidth: 1800,
                )
              : await widget.pickImage!(ImageSource.camera),
        _ =>
          widget.pickImage == null
              ? await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1800,
                )
              : await widget.pickImage!(ImageSource.gallery),
      };
      if (media == null || !mounted) return;
      final bytes = mediaType == 'image' ? await media.readAsBytes() : null;
      if (!mounted) return;
      setState(() {
        _media = media;
        _mediaType = mediaType;
        _imageBytes = bytes;
      });
    } catch (error) {
      if (mounted) _showMessage('เลือกสื่อไม่สำเร็จ: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isChoosingImageSource = false;
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final caption = _captionController.text.trim();
    final media = _media;
    if (caption.isEmpty) {
      _showMessage('กรุณาเขียนข้อความก่อนโพสต์', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _postService.createPost(
        caption: caption,
        location: _locationController.text.trim(),
        media: media,
        mediaType: _mediaType,
        communityId: widget.communityId,
      );
      if (!mounted) return;
      _captionController.clear();
      _locationController.clear();
      setState(() {
        _media = null;
        _mediaType = null;
        _imageBytes = null;
        _isSaving = false;
      });
      _showMessage('โพสต์ของคุณถูกเผยแพร่แล้ว');
      widget.onPosted();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('โพสต์ไม่สำเร็จ: $error', isError: true);
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
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.communityId == null ? 'สร้างโพสต์' : 'โพสต์ในชุมชน'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: const Color(0xFF071321),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'กำลังเผยแพร่โพสต์',
                      ),
                    )
                  : const Text('โพสต์'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _captionController,
            enabled: !_isSaving,
            minLines: 3,
            maxLines: 8,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'ข้อความ (จำเป็น)',
              hintText: 'แบ่งปันเรื่องราว ความคิด หรือสิ่งที่คุณสนใจ...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _locationController,
            enabled: !_isSaving,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'สถานที่ (ไม่บังคับ)',
              hintText: 'เพิ่มสถานที่ในโพสต์นี้',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            button: true,
            enabled: !_isSaving && !_isChoosingImageSource && !_isPickingImage,
            label: _media == null ? 'เพิ่มรูปภาพ' : 'เปลี่ยนรูปภาพ',
            hint: 'เลือกภาพ วิดีโอสั้นจากอัลบั้ม หรือถ่ายภาพใหม่',
            child: InkWell(
              onTap: _isSaving || _isChoosingImageSource || _isPickingImage
                  ? null
                  : _chooseMediaSource,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 260,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: _isPickingImage
                    ? const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'กำลังเลือกรูปภาพ',
                        ),
                      )
                    : _media == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'เพิ่มรูปภาพ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'เลือกรูปภาพ วิดีโอไม่เกิน 60 วินาที หรือถ่ายรูป',
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_mediaType == 'video')
                            const ColoredBox(
                              color: AppTheme.raisedSurfaceColor,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.video_file_outlined,
                                    size: 56,
                                    color: AppTheme.primaryColor,
                                  ),
                                  SizedBox(height: 8),
                                  Text('วิดีโอสั้นพร้อมโพสต์'),
                                ],
                              ),
                            )
                          else
                            Semantics(
                              image: true,
                              label: 'รูปภาพที่เลือก',
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: IconButton.filled(
                              onPressed: _isSaving
                                  ? null
                                  : () => setState(() {
                                      _media = null;
                                      _mediaType = null;
                                      _imageBytes = null;
                                    }),
                              tooltip: _mediaType == 'video'
                                  ? 'ลบวิดีโอ'
                                  : 'ลบรูปภาพ',
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'สามารถโพสต์ข้อความอย่างเดียว หรือเพิ่มรูปภาพ/วิดีโอสั้นได้',
            style: TextStyle(color: AppTheme.mutedTextColor),
          ),
        ],
      ),
    );
  }
}

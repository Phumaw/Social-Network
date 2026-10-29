import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_user.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final AppUser user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _authService = AuthService();
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _addressController;
  late bool _isPrivate;
  XFile? _profileImage;
  XFile? _bannerImage;
  Uint8List? _profileImageBytes;
  Uint8List? _bannerImageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _bioController = TextEditingController(text: widget.user.bio);
    _addressController = TextEditingController(text: widget.user.address);
    _isPrivate = widget.user.isPrivate;
  }

  Future<void> _pickImage({required bool isBanner}) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: isBanner ? 2000 : 1000,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (isBanner) {
          _bannerImage = image;
          _bannerImageBytes = bytes;
        } else {
          _profileImage = image;
          _profileImageBytes = bytes;
        }
      });
    } catch (error) {
      if (mounted) _showMessage('เลือกรูปภาพไม่สำเร็จ: $error', isError: true);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('กรุณาระบุชื่อผู้ใช้', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final user = await _authService.updateProfile(
        name: name,
        bio: _bioController.text.trim(),
        address: _addressController.text.trim(),
        isPrivate: _isPrivate,
        profileImage: _profileImage,
        bannerImage: _bannerImage,
      );
      if (!mounted) return;
      Navigator.pop(context, user);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('บันทึกโปรไฟล์ไม่สำเร็จ: $error', isError: true);
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
    _nameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขโปรไฟล์')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'ข้อมูลบัญชีของคุณ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 18),
          const Text(
            'ภาพหน้าปก',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _saving ? null : () => _pickImage(isBanner: true),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 150,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_bannerImageBytes != null)
                    Image.memory(_bannerImageBytes!, fit: BoxFit.cover)
                  else if (widget.user.bannerImage.isNotEmpty)
                    Image.network(
                      ApiService.resolveImageUrl(widget.user.bannerImage),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'แตะเพื่อเปลี่ยนภาพหน้าปก',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'รูปโปรไฟล์',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: _saving ? null : () => _pickImage(isBanner: false),
              borderRadius: BorderRadius.circular(60),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.primaryColor,
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : widget.user.profileImage.isNotEmpty
                        ? NetworkImage(
                            ApiService.resolveImageUrl(
                              widget.user.profileImage,
                            ),
                          )
                        : null,
                    child:
                        _profileImageBytes == null &&
                            widget.user.profileImage.isEmpty
                        ? Text(
                            widget.user.name.isEmpty
                                ? '?'
                                : widget.user.name.characters.first,
                            style: const TextStyle(
                              fontSize: 30,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.accentColor,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'ชื่อที่แสดง',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLength: 240,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'แนะนำตัว',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'ที่อยู่หรือพื้นที่ที่อยู่',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_isPrivate ? 'บัญชีส่วนตัว' : 'บัญชีสาธารณะ'),
            subtitle: Text(
              _isPrivate
                  ? 'คนอื่นต้องได้รับอนุมัติก่อนติดตามและดูโพสต์ของคุณ'
                  : 'ทุกคนสามารถดูโพสต์และติดตามคุณได้',
            ),
            value: _isPrivate,
            onChanged: (value) => setState(() => _isPrivate = value),
            activeThumbColor: AppTheme.primaryColor,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'บันทึกข้อมูล',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

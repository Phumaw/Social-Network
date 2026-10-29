import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ชุมชน', style: TextStyle(color: AppTheme.textDark)),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () {}), // ออกจากกลุ่ม
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('พื้นที่สำหรับแบ่งปันเรื่องราวและพูดคุยกับสมาชิก', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ชุมชนสาธารณะ', style: TextStyle(color: AppTheme.mutedTextColor)),
                    ElevatedButton(
                      onPressed: () {}, // ปุ่มเข้าร่วม / ออกจากกลุ่ม
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('เข้าร่วมแล้ว'),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('ฟีดในกลุ่ม', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Column(
              children: [
                Icon(Icons.forum_outlined, size: 36, color: AppTheme.mutedTextColor),
                SizedBox(height: 8),
                Text('ยังไม่มีโพสต์ในชุมชน', style: TextStyle(color: AppTheme.mutedTextColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
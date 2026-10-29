import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'group_detail_screen.dart';

class GroupListScreen extends StatelessWidget {
  const GroupListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('กลุ่มและชุมชน', style: TextStyle(color: AppTheme.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'สร้างกลุ่ม',
            icon: const Icon(Icons.add, color: AppTheme.textDark),
            onPressed: () => _showCreateGroupDialog(context),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                child: Icon(Icons.groups_outlined, color: AppTheme.accentColor),
              ),
              title: Text('ชุมชน $index'),
              subtitle: const Text('พื้นที่สำหรับแบ่งปันและพูดคุย'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupDetailScreen()));
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('สร้างกลุ่มใหม่'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            TextField(decoration: InputDecoration(hintText: 'ชื่อกลุ่ม')),
            SizedBox(height: 8),
            TextField(decoration: InputDecoration(hintText: 'คำอธิบายกลุ่ม')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('สร้างกลุ่ม', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
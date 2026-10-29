import 'package:flutter/material.dart';

import '../../models/chat_message.dart';
import '../../services/chat_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _chatService = ChatService();
  late Future<List<AppNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _load();
  }

  Future<List<AppNotification>> _load() async {
    final notifications = await _chatService.getNotifications();
    await _chatService.markNotificationsRead();
    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: FutureBuilder<List<AppNotification>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('โหลดการแจ้งเตือนไม่สำเร็จ: ${snapshot.error}'));
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(child: Text('ยังไม่มีการแจ้งเตือน'));
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    notification.actor.name.isEmpty
                        ? '?'
                        : notification.actor.name.characters.first,
                  ),
                ),
                title: Text(notification.actor.name),
                subtitle: Text(notification.message),
                trailing: notification.isRead
                    ? null
                    : const Icon(Icons.circle, size: 10, color: Colors.blue),
              );
            },
          );
        },
      ),
    );
  }
}

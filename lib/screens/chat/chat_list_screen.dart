import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import 'direct_chat_screen.dart';
import 'notification_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatService = ChatService();
  late Future<List<ChatConversation>> _conversations;
  late Future<List<AppNotification>> _notifications;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _conversations = _chatService.getConversations();
    _notifications = _chatService.getNotifications();
  }

  Future<void> _openChat(AppUser user) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => DirectChatScreen(user: user)),
    );
    if (mounted) setState(_refresh);
  }

  Future<void> _chooseContact() async {
    var query = '';
    var contacts = _chatService.getContacts();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'ค้นหาผู้ใช้',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      query = value;
                      setSheetState(() {
                        contacts = _chatService.getContacts(query: query);
                      });
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'เริ่มแชตกับสมาชิก',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<AppUser>>(
                    future: contacts,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'โหลดรายชื่อไม่สำเร็จ: ${snapshot.error}',
                          ),
                        );
                      }
                      final users = snapshot.data ?? [];
                      if (users.isEmpty) {
                        return const Center(child: Text('ไม่พบสมาชิก'));
                      }
                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) => ListTile(
                          leading: _avatar(users[index]),
                          title: Text(users[index].name),
                          subtitle: Text(users[index].bio),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _openChat(users[index]);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(AppUser user) {
    return CircleAvatar(
      backgroundColor: AppTheme.primaryColor,
      child: Text(user.name.isEmpty ? '?' : user.name.characters.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ข้อความแชต',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          FutureBuilder<List<AppNotification>>(
            future: _notifications,
            builder: (context, snapshot) {
              final hasUnread =
                  snapshot.data?.any((notification) => !notification.isRead) ??
                  false;
              return IconButton(
                tooltip: 'การแจ้งเตือน',
                onPressed: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                  if (mounted) setState(_refresh);
                },
                icon: Badge(
                  isLabelVisible: hasUnread,
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'เริ่มแชตใหม่',
            onPressed: _chooseContact,
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_refresh),
        child: FutureBuilder<List<ChatConversation>>(
          future: _conversations,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text('โหลดรายการแชตไม่สำเร็จ: ${snapshot.error}'),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(_refresh),
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ),
                ],
              );
            }
            final conversations = snapshot.data ?? [];
            if (conversations.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 150),
                  Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: AppTheme.mutedTextColor,
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('ยังไม่มีบทสนทนา')),
                  Center(child: Text('แตะไอคอนเขียนเพื่อเริ่มแชต')),
                ],
              );
            }
            return ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final preview = conversation.lastText.isNotEmpty
                    ? conversation.lastText
                    : conversation.lastMediaType == 'video'
                    ? 'ส่งวิดีโอ'
                    : 'ส่งรูปภาพ';
                return ListTile(
                  leading: _avatar(conversation.user),
                  title: Text(
                    conversation.user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openChat(conversation.user),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import 'api_service.dart';

class ChatService {
  Future<List<AppUser>> getContacts({String query = ''}) async {
    final suffix = query.trim().isEmpty
        ? ''
        : '?${Uri(queryParameters: {'q': query.trim()}).query}';
    final response = await ApiService.get('/chat/users$suffix');
    if (response is! List) {
      throw const ApiException('รูปแบบรายชื่อผู้ใช้ไม่ถูกต้อง');
    }
    return response
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList();
  }

  Future<List<ChatConversation>> getConversations() async {
    final response = await ApiService.get('/chat/conversations');
    if (response is! List) {
      throw const ApiException('รูปแบบรายการแชตไม่ถูกต้อง');
    }
    return response
        .whereType<Map<String, dynamic>>()
        .map(ChatConversation.fromJson)
        .toList();
  }

  Future<List<ChatMessage>> getMessages(String userId) async {
    final response = await ApiService.get(
      '/chat/conversations/${Uri.encodeComponent(userId)}/messages',
    );
    if (response is! List) {
      throw const ApiException('รูปแบบข้อความแชตไม่ถูกต้อง');
    }
    return response
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<void> sendMessage({
    required String userId,
    required String text,
    required XFile? media,
    required String mediaType,
  }) async {
    await ApiService.uploadChatMessage(
      userId: userId,
      text: text,
      media: media,
      mediaType: mediaType,
    );
  }

  Future<List<AppNotification>> getNotifications() async {
    final response = await ApiService.get('/chat/notifications');
    if (response is! List) {
      throw const ApiException('รูปแบบการแจ้งเตือนไม่ถูกต้อง');
    }
    return response
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<void> markNotificationsRead() async {
    await ApiService.put('/chat/notifications/read', {});
  }
}

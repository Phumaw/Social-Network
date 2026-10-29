import 'app_user.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String imageUrl;
  final String mediaType;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.imageUrl,
    this.mediaType = '',
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['from'] is Map<String, dynamic>
        ? json['from'] as Map<String, dynamic>
        : <String, dynamic>{};
    return ChatMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderId: (sender['id'] ?? sender['_id'] ?? json['from'] ?? '')
          .toString(),
      text: (json['text'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      mediaType: (json['mediaType'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class ChatConversation {
  final AppUser user;
  final String lastText;
  final String lastImageUrl;
  final String lastMediaType;
  final DateTime? updatedAt;

  const ChatConversation({
    required this.user,
    required this.lastText,
    required this.lastImageUrl,
    this.lastMediaType = '',
    this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final message = json['lastMessage'] is Map<String, dynamic>
        ? json['lastMessage'] as Map<String, dynamic>
        : <String, dynamic>{};
    return ChatConversation(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      lastText: (message['text'] ?? '').toString(),
      lastImageUrl: (message['imageUrl'] ?? '').toString(),
      lastMediaType: (message['mediaType'] ?? '').toString(),
      updatedAt: DateTime.tryParse((message['createdAt'] ?? '').toString()),
    );
  }
}

class AppNotification {
  final String id;
  final AppUser actor;
  final String message;
  final DateTime? createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.actor,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] is Map<String, dynamic>
        ? json['actor'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AppNotification(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      actor: AppUser.fromJson(actor),
      message: (json['message'] ?? '').toString(),
      isRead: json['readAt'] != null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/models/chat_message.dart';

void main() {
  group('ChatMessage media', () {
    test('reads video message metadata', () {
      final message = ChatMessage.fromJson({
        '_id': 'message-1',
        'from': {'_id': 'sender-1'},
        'text': 'ดูวิดีโอนี้',
        'imageUrl': '/uploads/video.mp4',
        'mediaType': 'video',
      });

      expect(message.id, 'message-1');
      expect(message.senderId, 'sender-1');
      expect(message.imageUrl, '/uploads/video.mp4');
      expect(message.mediaType, 'video');
    });

    test('keeps compatibility with older image messages', () {
      final message = ChatMessage.fromJson({
        'from': 'sender-1',
        'imageUrl': '/uploads/photo.jpg',
      });

      expect(message.imageUrl, '/uploads/photo.jpg');
      expect(message.mediaType, isEmpty);
    });
  });

  test('conversation preview identifies video messages', () {
    final conversation = ChatConversation.fromJson({
      'user': {'_id': 'user-2', 'name': 'สมาชิก'},
      'lastMessage': {'imageUrl': '/uploads/video.mp4', 'mediaType': 'video'},
    });

    expect(conversation.lastImageUrl, '/uploads/video.mp4');
    expect(conversation.lastMediaType, 'video');
  });
}

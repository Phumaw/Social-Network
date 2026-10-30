import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/models/app_user.dart';
import 'package:foodiehub/models/chat_message.dart';
import 'package:foodiehub/screens/chat/direct_chat_screen.dart';
import 'package:foodiehub/services/auth_service.dart';
import 'package:foodiehub/services/chat_service.dart';
import 'package:foodiehub/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';

const _pngBytes = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  0,
  0,
  3,
  1,
  1,
  0,
  201,
  254,
  146,
  239,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

void main() {
  late _FakeChatService chatService;
  late _FakeAuthService authService;

  Future<void> pumpChat(
    WidgetTester tester, {
    Future<XFile?> Function()? pickImage,
    Future<XFile?> Function()? pickVideo,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DirectChatScreen(
          user: const AppUser(id: 'friend-1', name: 'เพื่อน'),
          chatService: chatService,
          authService: authService,
          pickImage: pickImage,
          pickVideo: pickVideo,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    chatService = _FakeChatService();
    authService = _FakeAuthService();
  });

  testWidgets('offers image and video attachment choices', (tester) async {
    await pumpChat(tester);

    await tester.tap(find.byTooltip('แนบรูปภาพหรือวิดีโอ'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกรูปภาพ'), findsOneWidget);
    expect(find.text('เลือกวิดีโอสั้น (ไม่เกิน 60 วินาที)'), findsOneWidget);
  });

  testWidgets('sends a selected image with the message', (tester) async {
    final image = XFile.fromData(
      Uint8List.fromList(_pngBytes),
      name: 'photo.png',
      mimeType: 'image/png',
    );
    await pumpChat(tester, pickImage: () async => image);

    await tester.tap(find.byTooltip('แนบรูปภาพหรือวิดีโอ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกรูปภาพ'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ดูรูปนี้');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(chatService.sentMedia, same(image));
    expect(chatService.sentMediaType, 'image');
    expect(chatService.sentText, 'ดูรูปนี้');
    expect(chatService.sentUserId, 'friend-1');
  });

  testWidgets('sends a selected video without requiring message text', (
    tester,
  ) async {
    final video = XFile.fromData(
      Uint8List(0),
      name: 'clip.mp4',
      mimeType: 'video/mp4',
    );
    await pumpChat(tester, pickVideo: () async => video);

    await tester.tap(find.byTooltip('แนบรูปภาพหรือวิดีโอ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกวิดีโอสั้น (ไม่เกิน 60 วินาที)'));
    await tester.pumpAndSettle();

    expect(find.text('วิดีโอที่เลือก'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(chatService.sentMedia, same(video));
    expect(chatService.sentMediaType, 'video');
    expect(chatService.sentText, isEmpty);
  });

  testWidgets('uses high-contrast text colors for sent and received messages', (
    tester,
  ) async {
    chatService.messages = const [
      ChatMessage(
        id: 'sent',
        senderId: 'current-user',
        text: 'ข้อความที่ส่ง',
        imageUrl: '',
      ),
      ChatMessage(
        id: 'received',
        senderId: 'friend-1',
        text: 'ข้อความที่ได้รับ',
        imageUrl: '',
      ),
    ];
    await pumpChat(tester);

    expect(
      tester.widget<Text>(find.text('ข้อความที่ส่ง')).style?.color,
      Colors.white,
    );
    expect(
      tester.widget<Text>(find.text('ข้อความที่ได้รับ')).style?.color,
      AppTheme.textDark,
    );
  });

  testWidgets('renders a shared post in the conversation', (tester) async {
    chatService.messages = [
      ChatMessage.fromJson({
        'id': 'shared-message',
        'from': 'current-user',
        'text': '',
        'imageUrl': '',
        'sharedPost': {
          '_id': 'post-1',
          'user': {'_id': 'author-1', 'name': 'ผู้เขียน'},
          'caption': 'โพสต์ที่แบ่งปัน',
          'imageUrl': '',
        },
      }),
    ];
    await pumpChat(tester);

    expect(find.byKey(const Key('shared-post-post-1')), findsOneWidget);
    expect(find.text('โพสต์ที่แชร์'), findsOneWidget);
    expect(find.text('โพสต์ที่แบ่งปัน'), findsOneWidget);
  });

  testWidgets('shows when a shared post is no longer available', (
    tester,
  ) async {
    chatService.messages = [
      ChatMessage.fromJson({
        'id': 'shared-message',
        'from': 'current-user',
        'sharedPostUnavailable': true,
      }),
    ];
    await pumpChat(tester);

    expect(find.text('โพสต์นี้ไม่พร้อมใช้งาน'), findsOneWidget);
  });

  testWidgets('opens chat images in a pinch-to-zoom viewer', (tester) async {
    chatService.messages = const [
      ChatMessage(
        id: 'photo',
        senderId: 'friend-1',
        text: '',
        imageUrl: '/uploads/photo.jpg',
        mediaType: 'image',
      ),
    ];
    await pumpChat(tester);

    await tester.tap(find.byKey(const Key('chat-image-thumbnail')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 5);
    expect(find.byTooltip('ปิดรูปภาพ'), findsOneWidget);

    await tester.tap(find.byTooltip('ปิดรูปภาพ'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}

class _FakeChatService extends ChatService {
  List<ChatMessage> messages = [];
  String? sentUserId;
  String? sentText;
  XFile? sentMedia;
  String? sentMediaType;

  @override
  Future<List<ChatMessage>> getMessages(String userId) async => messages;

  @override
  Future<void> sendMessage({
    required String userId,
    required String text,
    required XFile? media,
    required String mediaType,
    String? sharedPostId,
  }) async {
    sentUserId = userId;
    sentText = text;
    sentMedia = media;
    sentMediaType = mediaType;
  }
}

class _FakeAuthService extends AuthService {
  @override
  Future<AppUser> refreshUser() async =>
      const AppUser(id: 'current-user', name: 'ผู้ใช้');
}

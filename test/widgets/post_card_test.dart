import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/models/app_user.dart';
import 'package:foodiehub/models/food_post.dart';
import 'package:foodiehub/services/chat_service.dart';
import 'package:foodiehub/services/post_service.dart';
import 'package:foodiehub/widgets/post_card.dart';

void main() {
  testWidgets('shows report and at least two quick reaction buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: _FakePostService(),
          ),
        ),
      ),
    );

    expect(find.byTooltip('รายงานโพสต์'), findsOneWidget);
    expect(find.byKey(const Key('reaction-Like')), findsOneWidget);
    expect(find.byKey(const Key('reaction-Dislike')), findsOneWidget);
    expect(find.byKey(const Key('reaction-Love')), findsOneWidget);
  });

  testWidgets('hides interactions when viewing without joining', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(),
            currentUserId: 'viewer',
            onChanged: () async {},
            interactionsEnabled: false,
            postService: _FakePostService(),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('reaction-Like')), findsNothing);
    expect(find.byTooltip('แสดงความคิดเห็น'), findsNothing);
    expect(find.byTooltip('รายงานโพสต์'), findsNothing);
  });

  testWidgets('shares a post with a selected chat contact', (tester) async {
    final service = _FakeChatService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: _FakePostService(),
            chatService: service,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('แชร์โพสต์'));
    await tester.pumpAndSettle();
    expect(find.text('แชร์โพสต์ให้เพื่อน'), findsOneWidget);
    await tester.tap(find.text('นารา'));
    await tester.pump();

    expect(service.sharedPostId, 'post-1');
    expect(service.recipientId, 'friend-1');
    expect(find.text('แชร์โพสต์ให้ นารา แล้ว'), findsOneWidget);
  });

  testWidgets('sends dislike reaction to the post service', (tester) async {
    final service = _FakePostService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: service,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('reaction-Dislike')));
    await tester.pumpAndSettle();

    expect(service.reactedPostId, 'post-1');
    expect(service.reactionType, 'Dislike');
  });

  testWidgets('dislike is also available in the full reaction picker', (
    tester,
  ) async {
    final service = _FakePostService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: service,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('แสดงอารมณ์เพิ่มเติม'));
    await tester.pumpAndSettle();
    expect(find.text('ไม่ถูกใจ'), findsOneWidget);
    await tester.tap(find.text('ไม่ถูกใจ'));
    await tester.pumpAndSettle();

    expect(service.reactionType, 'Dislike');
  });

  testWidgets('submits the selected report reason', (tester) async {
    final service = _FakePostService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: service,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('รายงานโพสต์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('สแปม'));
    await tester.tap(find.text('ส่งรายงาน'));
    await tester.pumpAndSettle();

    expect(service.reportedPostId, 'post-1');
    expect(service.reportedReason, 'Spam');
    expect(find.text('ส่งรายงานโพสต์แล้ว'), findsOneWidget);
  });

  testWidgets('follow button toggles follow state through the service', (
    tester,
  ) async {
    final service = _FakePostService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: service,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('ติดตามผู้โพสต์'));
    await tester.pumpAndSettle();
    expect(service.followedUserId, 'author');
    expect(find.byTooltip('เลิกติดตาม'), findsOneWidget);

    await tester.tap(find.byTooltip('เลิกติดตาม'));
    await tester.pumpAndSettle();
    expect(service.unfollowedUserId, 'author');
    expect(find.byTooltip('ติดตามผู้โพสต์'), findsOneWidget);
  });

  testWidgets('shows pending request action for a private account', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(followRequestPending: true),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: _FakePostService(),
          ),
        ),
      ),
    );

    expect(find.byTooltip('ยกเลิกคำขอติดตาม'), findsOneWidget);
  });

  testWidgets('shows the most-used reaction types on the post', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: _post(
              reactions: const [
                PostReaction(userId: 'user-1', type: 'Like'),
                PostReaction(userId: 'user-2', type: 'Like'),
                PostReaction(userId: 'user-3', type: 'Love'),
              ],
            ),
            currentUserId: 'viewer',
            onChanged: () async {},
            postService: _FakePostService(),
          ),
        ),
      ),
    );

    expect(find.text('👍 2'), findsOneWidget);
    expect(find.text('❤️ 1'), findsOneWidget);
  });

  testWidgets('tapping the post image opens the zoomable image viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PostCard(
                post: _post(imageUrl: 'https://example.test/post.jpg'),
                currentUserId: 'viewer',
                onChanged: () async {},
                postService: _FakePostService(),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('post-image')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('ปิดรูปภาพ'), findsOneWidget);
  });

  testWidgets('renders video posts with an in-feed video player', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PostCard(
                post: _post(
                  imageUrl: 'https://example.test/clip.mp4',
                  mediaType: 'video',
                ),
                currentUserId: 'viewer',
                onChanged: () async {},
                postService: _FakePostService(),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PostVideoPlayer), findsOneWidget);
    expect(find.byKey(const Key('post-image')), findsNothing);
  });

  testWidgets('tapping the post author avatar opens its image viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PostCard(
                post: _post(userImage: 'https://example.test/avatar.jpg'),
                currentUserId: 'viewer',
                onChanged: () async {},
                postService: _FakePostService(),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('post-author-avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('ปิดรูปภาพ'), findsOneWidget);
  });
}

FoodPost _post({
  List<PostReaction> reactions = const [],
  String imageUrl = '',
  String userImage = '',
  String mediaType = 'image',
  bool followRequestPending = false,
}) {
  return FoodPost(
    id: 'post-1',
    userId: 'author',
    userName: 'ผู้เขียน',
    caption: 'โพสต์ทดสอบ',
    imageUrl: imageUrl,
    mediaType: mediaType,
    userImage: userImage,
    reactions: reactions,
    followRequestPending: followRequestPending,
  );
}

class _FakePostService extends PostService {
  String? reportedPostId;
  String? reportedReason;
  String? followedUserId;
  String? unfollowedUserId;
  String? reactedPostId;
  String? reactionType;

  @override
  Future<void> reportPost(String postId, String reason) async {
    reportedPostId = postId;
    reportedReason = reason;
  }

  @override
  Future<void> setReaction(String postId, String? type) async {
    reactedPostId = postId;
    reactionType = type;
  }

  @override
  Future<Map<String, dynamic>> followUser(String userId) async {
    followedUserId = userId;
    return {'following': true, 'requestPending': false};
  }

  @override
  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    unfollowedUserId = userId;
    return {'following': false, 'requestPending': false};
  }
}

class _FakeChatService extends ChatService {
  String? recipientId;
  String? sharedPostId;

  @override
  Future<List<AppUser>> getContacts({String query = ''}) async => [
    const AppUser(id: 'friend-1', name: 'นารา', username: 'nara'),
  ];

  @override
  Future<void> sharePost({
    required String userId,
    required String postId,
  }) async {
    recipientId = userId;
    sharedPostId = postId;
  }
}

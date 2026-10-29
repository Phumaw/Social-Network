import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/models/app_user.dart';
import 'package:foodiehub/models/food_post.dart';
import 'package:foodiehub/screens/search/search_screen.dart';
import 'package:foodiehub/services/auth_service.dart';
import 'package:foodiehub/services/post_service.dart';

void main() {
  late _FakeAuthService authService;
  late _FakePostService postService;

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(authService: authService, postService: postService),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    authService = _FakeAuthService();
    postService = _FakePostService();
  });

  testWidgets('exposes an accessible search label and three search modes', (
    tester,
  ) async {
    await pumpSearch(tester);

    expect(find.text('โพสต์'), findsOneWidget);
    expect(find.text('ผู้ใช้'), findsOneWidget);
    expect(find.text('#แท็ก'), findsOneWidget);
    expect(find.bySemanticsLabel('ค้นหาโพสต์หรือแฮชแท็ก'), findsWidgets);
  });

  testWidgets('searches posts with the entered query', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'อาหารไทย');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(postService.queries.last, 'อาหารไทย');
  });

  testWidgets('trims whitespace before searching', (tester) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), '  ขนม  ');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(postService.queries.last, 'ขนม');
  });

  testWidgets('switches to user search and searches by username', (
    tester,
  ) async {
    authService.searchResults = [
      const AppUser(id: 'user-1', name: 'นารา', username: 'nara'),
    ];
    await pumpSearch(tester);
    await tester.tap(find.text('ผู้ใช้'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '@nara');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(authService.queries.last, '@nara');
    expect(find.text('นารา'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('@nara')),
      findsOneWidget,
    );
  });

  testWidgets('marks private accounts accessibly in user results', (
    tester,
  ) async {
    authService.searchResults = [
      const AppUser(id: 'user-2', name: 'สมาชิกส่วนตัว', isPrivate: true),
    ];
    await pumpSearch(tester);
    await tester.tap(find.text('ผู้ใช้'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('บัญชีส่วนตัว'), findsOneWidget);
  });

  testWidgets('shows an empty state for user search results', (tester) async {
    await pumpSearch(tester);
    await tester.tap(find.text('ผู้ใช้'));
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบผู้ใช้ที่ตรงกับการค้นหา'), findsOneWidget);
  });

  testWidgets('adds a hash prefix in hashtag mode', (tester) async {
    await pumpSearch(tester);
    await tester.tap(find.text('#แท็ก'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'อาหาร');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(postService.queries.last, '#อาหาร');
  });

  testWidgets('does not duplicate an existing hashtag prefix', (tester) async {
    await pumpSearch(tester);
    await tester.tap(find.text('#แท็ก'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '#อาหาร');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(postService.queries.last, '#อาหาร');
  });

  testWidgets('hides post sorting controls in user mode', (tester) async {
    await pumpSearch(tester);
    await tester.tap(find.text('ผู้ใช้'));
    await tester.pumpAndSettle();

    expect(find.text('ล่าสุด'), findsNothing);
    expect(find.text('ยอดนิยม'), findsNothing);
    expect(find.text('มีสถานที่'), findsNothing);
  });

  testWidgets('coalesces rapid text changes through debounce', (tester) async {
    await pumpSearch(tester);
    final initialQueryCount = postService.queries.length;
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(postService.queries.length, initialQueryCount + 1);
    expect(postService.queries.last, 'abc');
  });

  testWidgets('ignores a stale response after a newer search starts', (
    tester,
  ) async {
    final oldSearch = Completer<List<FoodPost>>();
    postService.onSearch = (query) {
      if (query == 'old') return oldSearch.future;
      return Future.value([]);
    };
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'new');
    oldSearch.complete([_post('stale')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('stale-post-caption'), findsNothing);
    expect(postService.queries.last, 'new');
  });

  testWidgets('shows a retry action when search fails', (tester) async {
    postService.failure = StateError('offline');
    await pumpSearch(tester);

    expect(find.textContaining('ค้นหาไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
  });
}

FoodPost _post(String id) => FoodPost(
  id: id,
  userId: 'user-1',
  userName: 'สมาชิก',
  caption: '$id-post-caption',
  imageUrl: '',
);

class _FakeAuthService extends AuthService {
  final List<String> queries = [];
  List<AppUser> searchResults = [];

  @override
  Future<AppUser> refreshUser() async =>
      const AppUser(id: 'current-user', name: 'ผู้ใช้');

  @override
  Future<List<AppUser>> searchUsers(String query) async {
    queries.add(query);
    return searchResults;
  }
}

class _FakePostService extends PostService {
  final List<String> queries = [];
  Future<List<FoodPost>> Function(String query)? onSearch;
  Object? failure;

  @override
  Future<List<FoodPost>> getPosts({
    String query = '',
    String sort = 'recent',
    bool withLocation = false,
    String? communityId,
    String? userId,
  }) async {
    queries.add(query);
    if (failure != null) throw failure!;
    return onSearch?.call(query) ?? [];
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/main.dart';
import 'package:foodiehub/screens/auth/login_screen.dart';
import 'package:foodiehub/screens/auth/register_screen.dart';
import 'package:foodiehub/screens/chat/chat_list_screen.dart';
import 'package:foodiehub/screens/feed/home_screen.dart';
import 'package:foodiehub/screens/post/create_post_screen.dart';
import 'package:foodiehub/screens/profile/profile_screen.dart';
import 'package:foodiehub/screens/search/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? token;
  Object? storageError;
  int reads = 0;
  Completer<String?>? pendingToken;

  setUp(() {
    token = null;
    storageError = null;
    reads = 0;
    pendingToken = null;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storageChannel, (call) async {
          if (call.method != 'read') {
            throw MissingPluginException('Unexpected method: ${call.method}');
          }
          reads++;
          if (storageError != null) throw storageError!;
          if (pendingToken != null) return pendingToken!.future;
          return token;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storageChannel, null);
  });

  testWidgets('application exposes its title and hides the debug banner', (
    tester,
  ) async {
    await tester.pumpWidget(const SocialNetworkApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Social Network');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });

  testWidgets('missing token opens the login screen', (tester) async {
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('empty token opens the login screen', (tester) async {
    token = '';
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('non-empty token opens the main navigation screen', (
    tester,
  ) async {
    token = 'session-token';
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pump();

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('shows a loading indicator while checking the token', (
    tester,
  ) async {
    pendingToken = Completer<String?>();
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pendingToken!.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('shows an error and retry action when token lookup fails', (
    tester,
  ) async {
    storageError = PlatformException(
      code: 'storage-error',
      message: 'Storage unavailable',
    );
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ตรวจสอบสถานะเข้าสู่ระบบไม่สำเร็จ'),
      findsOneWidget,
    );
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
  });

  testWidgets('retry checks the session again after a lookup error', (
    tester,
  ) async {
    storageError = PlatformException(code: 'storage-error');
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pumpAndSettle();

    storageError = null;
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('application configures all expected named routes', (
    tester,
  ) async {
    await tester.pumpWidget(const SocialNetworkApp());

    final routes = tester.widget<MaterialApp>(find.byType(MaterialApp)).routes!;
    expect(routes.keys, containsAll(['/login', '/register', '/main']));
  });

  testWidgets('register route resolves to the register screen', (tester) async {
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AuthGate));

    Navigator.of(context).pushNamed('/register');
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('main navigation shows five destinations for a signed-in user', (
    tester,
  ) async {
    token = 'session-token';
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pump();

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('หน้าแรก'), findsOneWidget);
    expect(find.text('ค้นหา'), findsOneWidget);
    expect(find.text('โพสต์'), findsOneWidget);
    expect(find.text('แชต'), findsOneWidget);
    expect(find.text('โปรไฟล์'), findsOneWidget);
  });

  testWidgets('navigation tabs display their corresponding screens', (
    tester,
  ) async {
    token = 'session-token';
    await tester.pumpWidget(const SocialNetworkApp());
    await tester.pump();

    await tester.tap(_navigationItem('ค้นหา'));
    await tester.pump();
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.tap(_navigationItem('โพสต์'));
    await tester.pump();
    expect(find.byType(CreatePostScreen), findsOneWidget);

    await tester.tap(_navigationItem('แชต'));
    await tester.pump();
    expect(find.byType(ChatListScreen), findsOneWidget);

    await tester.tap(_navigationItem('โปรไฟล์'));
    await tester.pump();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}

Finder _navigationItem(String label) => find.descendant(
  of: find.byType(BottomNavigationBar),
  matching: find.text(label),
);

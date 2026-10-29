import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/models/app_user.dart';
import 'package:foodiehub/models/food_post.dart';
import 'package:foodiehub/screens/auth/login_screen.dart';
import 'package:foodiehub/screens/auth/register_screen.dart';
import 'package:foodiehub/screens/auth/forgot_password_screen.dart';
import 'package:foodiehub/services/auth_service.dart';
import 'package:foodiehub/theme/app_theme.dart';

void main() {
  test('app theme uses white surfaces and legible foreground colors', () {
    expect(AppTheme.themeData.brightness, Brightness.light);
    expect(AppTheme.themeData.scaffoldBackgroundColor, Colors.white);
    expect(AppTheme.themeData.colorScheme.onSurface, AppTheme.textDark);
  });

  testWidgets('login screen displays Social Network email sign-in form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Social Network'), findsOneWidget);
    expect(find.text('อีเมล'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน'), findsOneWidget);
    expect(find.text('ชื่อผู้ใช้'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'รหัสผ่าน',
      ),
      findsOneWidget,
    );
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(find.text('สมัครสมาชิก'), findsOneWidget);
  });

  testWidgets('login rejects invalid email without calling authentication', (
    WidgetTester tester,
  ) async {
    final authService = FakeLoginAuthService();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: authService)),
    );

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pump();

    expect(find.text('กรุณากรอกอีเมลให้ถูกต้อง'), findsOneWidget);
    expect(authService.loginCalls, 0);
  });

  testWidgets('login submits email and password to authentication service', (
    WidgetTester tester,
  ) async {
    final authService = FakeLoginAuthService();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: authService)),
    );

    await tester.enterText(find.byType(TextField).first, 'nara@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(authService.loginCalls, 1);
    expect(authService.submittedEmail, 'nara@example.com');
    expect(authService.submittedPassword, 'secret123');
  });

  testWidgets('register screen asks for username without a name field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    expect(find.text('ชื่อผู้ใช้ (a-z, 0-9, _)'), findsOneWidget);
    expect(find.text('ชื่อ-นามสกุล'), findsNothing);
    expect(find.text('อีเมล'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'รหัสผ่าน',
      ),
      findsOneWidget,
    );
    expect(find.text('ยืนยันรหัสผ่านอีกครั้ง'), findsOneWidget);
    expect(find.textContaining('ที่อยู่'), findsNothing);
    expect(find.text('กรอกรหัสผ่านเพื่อวัดความรัดกุม'), findsOneWidget);
  });

  testWidgets('register form fields stay narrow on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(
        tester.getSize(find.byWidget(field)).width,
        lessThanOrEqualTo(440),
      );
    }
  });

  testWidgets('login form fields stay narrow on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(
        tester.getSize(find.byWidget(field)).width,
        lessThanOrEqualTo(440),
      );
    }
  });

  testWidgets('register password starts hidden and can be revealed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    final passwordField = tester.widget<TextField>(
      find.byType(TextField).at(2),
    );

    expect(passwordField.obscureText, isTrue);
    await tester.tap(find.byTooltip('แสดงรหัสผ่าน'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).obscureText,
      isFalse,
    );
  });

  testWidgets('register password strength bar changes from weak to strong', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    final barFinder = find.byKey(const Key('password-strength-bar'));

    await tester.enterText(find.byType(TextField).at(2), 'weak');
    await tester.pump();
    final weakBar = tester.widget<LinearProgressIndicator>(barFinder);
    expect(weakBar.color, Colors.red.shade700);
    expect(find.text('รหัสผ่านรัดกุมน้อย'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'StrongPass1!');
    await tester.pump();
    final strongBar = tester.widget<LinearProgressIndicator>(barFinder);
    expect(strongBar.color, Colors.green.shade700);
    expect(find.text('รหัสผ่านรัดกุมมาก'), findsOneWidget);
  });

  testWidgets('register rejects non-matching password confirmation', (
    WidgetTester tester,
  ) async {
    final authService = FakeRegisterAuthService();
    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(authService: authService)),
    );

    await tester.enterText(find.byType(TextField).at(0), 'nara_1');
    await tester.enterText(find.byType(TextField).at(1), 'nara@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'StrongPass1!');
    await tester.enterText(find.byType(TextField).at(3), 'DifferentPass1!');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน'), findsOneWidget);
    expect(authService.registerCalls, 0);
  });

  testWidgets('forgot password screen asks for registered email', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));

    expect(find.text('ลืมรหัสผ่าน'), findsOneWidget);
    expect(find.text('อีเมลที่สมัคร'), findsOneWidget);
    expect(find.text('ส่งรหัสยืนยัน'), findsOneWidget);
    expect(find.text('รหัสยืนยัน 6 หลัก'), findsNothing);
  });

  test('parses populated MongoDB profile and food-post data', () {
    final user = AppUser.fromJson({
      '_id': 'user-1',
      'name': 'Nara',
      'username': 'nara_1',
      'email': 'nara@example.com',
      'bio': 'ชอบอาหารไทย',
      'bannerImage': '/uploads/banner.jpg',
    });
    final post = FoodPost.fromJson({
      '_id': 'post-1',
      'user': {'_id': 'user-1', 'name': 'Nara', 'profileImage': ''},
      'caption': 'ข้าวผัดอร่อยมาก',
      'imageUrl': '/uploads/food.jpg',
      'location': 'ร้านอร่อย',
      'reactions': [
        {
          'user': {'_id': 'user-2'},
          'type': 'Love',
        },
      ],
      'comments': [
        {
          '_id': 'comment-1',
          'user': {'_id': 'user-2', 'name': 'Mali'},
          'text': 'น่าทาน',
        },
      ],
      'isFollowedByMe': true,
      'mediaType': 'video',
    });

    expect(user.id, 'user-1');
    expect(user.username, 'nara_1');
    expect(user.bannerImage, '/uploads/banner.jpg');
    expect(post.userId, 'user-1');
    expect(post.userName, 'Nara');
    expect(post.reactionBy('user-2'), 'Love');
    expect(post.comments.single.userName, 'Mali');
    expect(post.isFollowedByMe, isTrue);
    expect(post.mediaType, 'video');
  });
}

class FakeLoginAuthService extends AuthService {
  int loginCalls = 0;
  String? submittedEmail;
  String? submittedPassword;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    loginCalls++;
    submittedEmail = email;
    submittedPassword = password;
    return {'success': false, 'message': 'ข้อมูลเข้าสู่ระบบไม่ถูกต้อง'};
  }
}

class FakeRegisterAuthService extends AuthService {
  int registerCalls = 0;

  @override
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String address,
  }) async {
    registerCalls++;
    return {'success': true, 'message': 'ลงทะเบียนสำเร็จ'};
  }
}

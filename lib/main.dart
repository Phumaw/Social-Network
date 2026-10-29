import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/feed/home_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/post/create_post_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const SocialNetworkApp());
}

class SocialNetworkApp extends StatelessWidget {
  const SocialNetworkApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Network',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainNavigationScreen(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<bool> _hasSession;

  @override
  void initState() {
    super.initState();
    _hasSession = ApiService.readToken().then((token) => token != null && token.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSession,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ตรวจสอบสถานะเข้าสู่ระบบไม่สำเร็จ: ${snapshot.error}'),
                  TextButton(
                    onPressed: () => setState(() {
                      _hasSession =
                          ApiService.readToken().then((token) => token != null && token.isNotEmpty);
                    }),
                    child: const Text('ลองอีกครั้ง'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const MainNavigationScreen() : const LoginScreen();
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  int _feedVersion = 0;

  List<Widget> get _pages => [
        HomeScreen(key: ValueKey(_feedVersion)),
        const SearchScreen(),
        CreatePostScreen(onPosted: () {
          setState(() {
            _feedVersion++;
            _currentIndex = 0;
          });
        }),
        const ChatListScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.borderColor, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: AppTheme.accentColor,
          unselectedItemColor: AppTheme.mutedTextColor,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.surfaceColor,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'ค้นหา'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'โพสต์'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'แชต'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'โปรไฟล์'),
          ],
        ),
      ),
    );
  }
}
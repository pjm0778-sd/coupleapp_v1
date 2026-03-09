import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/couple/screens/couple_connect_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/settings/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const CoupleApp());
}

class CoupleApp extends StatelessWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Couple',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {'/': (_) => const AppRouter()},
    );
  }
}

/// 로그인 상태 + 커플 연결 상태에 따라 화면 분기
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, authSnap) {
        final session =
            authSnap.data?.session ?? supabase.auth.currentSession;

        // 미로그인
        if (session == null) return const LoginScreen();

        // 로그인 → 커플 연결 여부 확인
        return FutureBuilder<Map<String, dynamic>>(
          key: ValueKey(session.user.id),
          future: supabase
              .from('profiles')
              .select('couple_id')
              .eq('id', session.user.id)
              .single(),
          builder: (context, profileSnap) {
            if (!profileSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final coupleId = profileSnap.data?['couple_id'];
            if (coupleId == null) return const CoupleConnectScreen();
            return const MainShell();
          },
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: '캘린더',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}

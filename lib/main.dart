import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/notification_manager.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/home/screens/home_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/schedule/screens/auto_registration_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/notifications/screens/notification_history_screen.dart';
import 'package:flutter/services.dart' as import_services;

import 'package:intl/date_symbol_data_local.dart';

/// 탭 전환 알림
class TabSwitchNotification extends Notification {
  final int tabIndex;
  TabSwitchNotification(this.tabIndex);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await NotificationManager().initialize();
  runApp(const CoupleApp());
}

class CoupleApp extends StatelessWidget {
  const CoupleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '커플듀티',
      theme: AppTheme.light.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
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
        final session = authSnap.data?.session ?? supabase.auth.currentSession;

        // 미로그인
        if (session == null) return const LoginScreen();

        // 로그인 → 커플 연결 여부 확인
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(session.user.id),
          future: supabase
              .from('profiles')
              .select('couple_id, onboarding_completed')
              .eq('id', session.user.id)
              .maybeSingle(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            // null  → 기존 유저(컬럼 없거나 미설정) → MainShell
            // false → 신규 유저(온보딩 미완료)     → OnboardingFlow
            // true  → 온보딩 완료                  → MainShell
            final onboardingCompleted =
                profileSnap.data?['onboarding_completed'] as bool?;
            if (onboardingCompleted == false) return const OnboardingFlow();
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _lastBackPressedTime;

  static const List<Widget> _screens = [
    HomeScreen(),
    CalendarScreen(),
    AutoRegistrationScreen(),
    NotificationHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationManager().clearAllNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationManager().clearAllNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_currentIndex != 0) {
          // 다른 탭에서 홈으로 이동
          setState(() => _currentIndex = 0);
        } else {
          // 홈에서 앱 종료 확인
          final now = DateTime.now();
          if (_lastBackPressedTime == null ||
              now.difference(_lastBackPressedTime!) >
                  const Duration(milliseconds: 1500)) {
            _lastBackPressedTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('한 번 더 누르면 앱이 종료됩니다'),
                duration: Duration(milliseconds: 1500),
              ),
            );
          } else {
            // 두 번 누름: 앱 종료 허용 (시스템에 백엔드/스택 팝 요청)
            // 안드로이드에서는 SystemNavigator.pop()을 호출하는 방식 사용
            import_services.SystemNavigator.pop();
          }
        }
      },
      child: NotificationListener<TabSwitchNotification>(
        onNotification: (notification) {
          setState(() => _currentIndex = notification.tabIndex);
          return true;
        },
        child: Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
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
                  label: '우리의 달력',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.document_scanner_outlined),
                  activeIcon: Icon(Icons.document_scanner_rounded),
                  label: '일정 자동등록',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_outlined),
                  activeIcon: Icon(Icons.notifications_rounded),
                  label: '알림',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: '설정',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'core/notification_manager.dart';
import 'core/fcm_service.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/home/screens/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' as import_services;

import 'package:intl/date_symbol_data_local.dart';
import 'core/home_widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  await initializeDateFormatting('ko_KR', null);
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  debugPrint('[Auth] initialSession=${supabase.auth.currentSession?.user.id}');
  supabase.auth.onAuthStateChange.listen((data) {
    debugPrint(
      '[Auth] event=${data.event} sessionUser=${data.session?.user.id}',
    );
  });

  try {
    await NotificationManager().initialize();
  } catch (e) {
    // macOS에서 플러그인 설정 누락 시 앱 부팅이 막히지 않도록 안전하게 진행
    debugPrint('[Notification] init skipped: $e');
  }
  await HomeWidgetService.init();
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      debugPrint('[Firebase] initialized successfully');
    } catch (e) {
      // iOS: AppDelegate method swizzling이 이미 configure()를 호출한 경우 무시
      debugPrint('[Firebase] init skipped (already configured): $e');
    }
    try {
      await FcmService().initialize();
      debugPrint('[FCM] service initialized');
    } catch (e) {
      debugPrint('[FCM] service init failed: $e');
    }
  }
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
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

        Widget child;

        if (session == null) {
          // 미로그인
          child = const LoginScreen(key: ValueKey('login'));
        } else {
          // 로그인 → 커플 연결 여부 확인
          child = FutureBuilder<Map<String, dynamic>?>(
            key: ValueKey(session.user.id),
            future: supabase
                .from('profiles')
                .select('couple_id, onboarding_completed')
                .eq('id', session.user.id)
                .maybeSingle(),
            builder: (context, profileSnap) {
              if (profileSnap.connectionState == ConnectionState.waiting) {
                return const SplashScreen(key: ValueKey('splash'));
              }
              // null  → 기존 유저(컬럼 없거나 미설정) → MainShell
              // false → 신규 유저(온보딩 미완료)     → OnboardingFlow
              // true  → 온보딩 완료                  → MainShell
              final onboardingCompleted =
                  profileSnap.data?['onboarding_completed'] as bool?;
              if (onboardingCompleted == false) {
                return const OnboardingFlow(key: ValueKey('onboarding'));
              }
              return const MainShell(key: ValueKey('main'));
            },
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: child,
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
  DateTime? _lastBackPressedTime;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationManager().clearAllNotifications();
    _notificationService.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationService.dispose();
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
      },
      child: const Scaffold(body: HomeScreen()),
    );
  }
}

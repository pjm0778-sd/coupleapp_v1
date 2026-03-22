import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_manager.dart';
import 'supabase_client.dart';
import '../features/notifications/models/notification.dart';

/// 백그라운드 메시지 핸들러 — 반드시 최상위 함수여야 함
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // 백그라운드에서 수신된 FCM 메시지 처리 (히스토리는 포그라운드에서 추가)
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    if (kIsWeb) return;

    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // 권한 요청 (iOS)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM 토큰 저장 — 로그인 상태일 때만, 로그인 후에도 재시도
    await _saveToken();
    _fcm.onTokenRefresh.listen(_updateToken);
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) _saveToken();
    });

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 앱이 백그라운드에서 알림 탭으로 열린 경우
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
  }

  Future<String?> getToken() => _fcm.getToken();

  Future<void> _saveToken() async {
    try {
      final token = await _fcm.getToken();
      debugPrint('[FCM] getToken result: $token');
      if (token != null) await _updateToken(token);
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
    }
  }

  Future<void> _updateToken(String token) async {
    final userId = supabase.auth.currentUser?.id;
    debugPrint('[FCM] userId: $userId');
    if (userId == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('[FCM] token saved successfully');
    } catch (e) {
      debugPrint('[FCM] token save error: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] as String? ?? '알림';
    final body = notification?.body ?? data['body'] as String?;
    final typeStr = data['type'] as String?;
    final type = _parseType(typeStr);

    // 알림 설정 체크
    final settings = NotificationManager().settings;
    final enabled = switch (type) {
      NotificationType.scheduleAdded => settings.scheduleAdded,
      NotificationType.scheduleUpdated => settings.scheduleUpdated,
      NotificationType.scheduleDeleted => settings.scheduleDeleted,
      NotificationType.commentAdded => settings.commentAdded,
      _ => true,
    };
    if (!enabled) return;

    // 로컬 알림 표시 + 히스토리 추가
    await NotificationManager().showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      type: type,
    );
  }

  void _handleMessageOpened(RemoteMessage message) {
    // 필요 시 특정 화면으로 이동하는 네비게이션 로직 추가
  }

  NotificationType _parseType(String? typeStr) {
    return switch (typeStr) {
      'schedule_added' => NotificationType.scheduleAdded,
      'schedule_updated' => NotificationType.scheduleUpdated,
      'schedule_deleted' => NotificationType.scheduleDeleted,
      'comment_added' => NotificationType.commentAdded,
      _ => NotificationType.scheduleAdded,
    };
  }
}

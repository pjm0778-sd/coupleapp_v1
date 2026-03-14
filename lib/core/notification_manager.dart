import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/notifications/models/notification.dart';
import '../features/notifications/models/notification_settings.dart';
import '../shared/models/schedule.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationSettings _settings = const NotificationSettings();
  List<AppNotification> _history = [];
  StreamController<List<AppNotification>>? _historyController;

  List<AppNotification> get history => _history;
  NotificationSettings get settings => _settings;

  // Web 권한 (Web 전용)
  final bool _webPermissionGranted = false;
  bool get webPermissionGranted => _webPermissionGranted;

  Stream<List<AppNotification>> get historyStream {
    _historyController ??= StreamController<List<AppNotification>>.broadcast();
    return _historyController!.stream;
  }

  // ---------------------------------------------------------------------------
  // 초기화
  // ---------------------------------------------------------------------------
  Future<void> initialize() async {
    await _loadSettings();

    if (kIsWeb) return; // Web은 시스템 알림 미지원
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // 알림 클릭 핸들링(필요 시 확장)
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 권한 요청
  // ---------------------------------------------------------------------------

  /// Android 13+ / iOS 알림 권한 요청. true = 허용
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  // Web용 (기존 인터페이스 호환)
  Future<String> requestWebNotificationPermission() async {
    if (!kIsWeb) return 'not_web';
    return 'not_implemented';
  }

  Future<void> showWebNotification({
    required String title,
    String? body,
  }) async {
    if (!kIsWeb) return;
  }

  // ---------------------------------------------------------------------------
  // 알림 발송
  // ---------------------------------------------------------------------------
  Future<void> showLocalNotification({
    required int id,
    required String title,
    String? body,
    NotificationType? type,
  }) async {
    // 내부 히스토리 추가
    if (type != null) {
      addToHistory(
        AppNotification.fromRealtime(
          id: '${id}_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          body: body,
          type: type,
        ),
      );
    }

    if (kIsWeb) return; // Web은 시스템 알림 미지원
    const androidDetails = AndroidNotificationDetails(
      'couple_app_channel',
      '커플 앱 알림',
      channelDescription: '커플 앱의 일정 및 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  Future<void> clearAllNotifications() async {
    if (!kIsWeb) {
      await _plugin.cancelAll();
    }
  }

  // ---------------------------------------------------------------------------
  // 히스토리 관리
  // ---------------------------------------------------------------------------
  void addToHistory(AppNotification notification) {
    _history.insert(0, notification);
    _historyController?.add(_history);
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
  }

  void markAllAsRead() {
    _history = _history.map((n) => n.markAsRead()).toList();
    _historyController?.add(_history);
  }

  // ---------------------------------------------------------------------------
  // 설정 저장/로드 (SharedPreferences)
  // ---------------------------------------------------------------------------
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notification_settings');
      if (json != null) {
        _settings = NotificationSettings.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      _settings = const NotificationSettings();
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'notification_settings',
        jsonEncode(_settings.toJson()),
      );
    } catch (_) {}
  }

  void updateSettings(NotificationSettings newSettings) {
    _settings = newSettings;
    _saveSettings();
  }

  // ---------------------------------------------------------------------------
  // 일정 기반 알림 체크
  // ---------------------------------------------------------------------------
  Future<void> checkBothOffAndSchedule({
    required List<Schedule> mySchedules,
    required List<Schedule> partnerSchedules,
    required DateTime today,
  }) async {
    if (!_settings.bothOff) return;

    final myOffDates = mySchedules.map((s) => s.date).toSet();
    final partnerOffDates = partnerSchedules.map((s) => s.date).toSet();
    final commonOffDates = myOffDates.intersection(partnerOffDates);

    if (commonOffDates.contains(today)) {
      await showLocalNotification(
        id: 1001,
        title: '둘 다 쉬는 날',
        body: '오늘 둘 다 휴무예요. 데이트 하시겠어요?',
        type: NotificationType.bothOff,
      );
    }
  }

  Future<void> checkDateBefore({
    required List<Schedule> schedules,
    required DateTime tomorrow,
  }) async {
    if (!_settings.dateBefore) return;

    final datePlan = schedules
        .where((s) => s.isDate && s.date == tomorrow)
        .toList();

    if (datePlan.isNotEmpty) {
      await showLocalNotification(
        id: 2000 + tomorrow.day,
        title: '내일 데이트',
        body: '내일 ${tomorrow.month}월 ${tomorrow.day}일 데이트 예정이에요.',
        type: NotificationType.dateBefore,
      );
    }
  }

  Future<void> checkDateToday({
    required List<Schedule> schedules,
    required DateTime today,
  }) async {
    if (!_settings.dateToday) return;

    final datePlan = schedules
        .where((s) => s.isDate && s.date == today)
        .toList();

    if (datePlan.isNotEmpty) {
      await showLocalNotification(
        id: 3000 + today.day,
        title: '오늘 데이트',
        body: '오늘 ${today.month}월 ${today.day}일 데이트 날이에요!',
        type: NotificationType.dateToday,
      );
    }
  }

  /// 내 애인 일정 변경 알림 (일정 추가/수정/삭제 시 호출)
  Future<void> notifyScheduleChanged({
    required NotificationType type,
    required String scheduleTitle,
  }) async {
    final enabled = switch (type) {
      NotificationType.scheduleAdded => _settings.scheduleAdded,
      NotificationType.scheduleDeleted => _settings.scheduleDeleted,
      NotificationType.scheduleUpdated => _settings.scheduleUpdated,
      _ => false,
    };
    if (!enabled) return;

    final actionLabel = switch (type) {
      NotificationType.scheduleAdded => '추가되었어요',
      NotificationType.scheduleDeleted => '삭제되었어요',
      NotificationType.scheduleUpdated => '수정되었어요',
      _ => '변경했어요',
    };

    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '내 애인 일정 알림',
      body: '내 애인이 "$scheduleTitle" 일정을 $actionLabel',
      type: type,
    );
  }
}

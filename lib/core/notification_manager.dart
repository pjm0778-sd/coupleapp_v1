import 'dart:async';
import 'dart:html' as html show Notification;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/notifications/models/notification.dart';
import '../features/notifications/models/notification_settings.dart';
import '../../shared/models/schedule.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  NotificationSettings _settings = const NotificationSettings();
  List<AppNotification> _history = [];
  StreamController<List<AppNotification>>? _historyController;

  List<AppNotification> get history => _history;
  NotificationSettings get settings => _settings;

  bool _webPermissionGranted = false;
  bool get webPermissionGranted => _webPermissionGranted;

  Stream<List<AppNotification>> get historyStream {
    _historyController ??= StreamController<List<AppNotification>>.broadcast();
    return _historyController!.stream;
  }

  Future<void> initialize() async {
    _loadSettings();
  }

  void _loadSettings() {
    // TODO: SharedPreferences에서 로드
    // 현재는 기본값 사용
  }

  void _saveSettings() {
    // TODO: SharedPreferences에 저장
  }

  void updateSettings(NotificationSettings newSettings) {
    _settings = newSettings;
    _saveSettings();
  }

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

  Future<String> requestWebNotificationPermission() async {
    if (!kIsWeb) return 'not_web';

    try {
      final permission = await html.Notification.requestPermission();
      _webPermissionGranted = permission == 'granted';
      return _webPermissionGranted ? 'granted' : 'denied';
    } catch (e) {
      return 'error';
    }
  }

  Future<void> showWebNotification({
    required String title,
    String? body,
  }) async {
    if (!kIsWeb || !_webPermissionGranted) return;

    try {
      html.Notification(
        title,
        body: body,
        icon: '/icon.png',
      );
    } catch (e) {
      // 브라우저가 알림을 지원하지 않는 경우 무시
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    String? body,
    NotificationType? type,
  }) async {
    // 웹에서는 브라우저 알림 사용
    if (kIsWeb) {
      await showWebNotification(title: title, body: body);
      return;
    }

    // 모바일/데스크톱에서는 향후 추가 (현재 web만 구현)
  }

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
        title: '💖 둘 다 쉬는 날!',
        body: '오늘 둘 다 휴무네요 데이트 하시겠어요?',
        type: NotificationType.bothOff,
      );
      addToHistory(AppNotification.fromRealtime(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '💖 둘 다 쉬는 날!',
        body: '오늘 둘 다 휴무네요 데이트 하시겠어요?',
        type: NotificationType.bothOff,
      ));
    }
  }

  Future<void> checkDateBefore({
    required List<Schedule> schedules,
    required DateTime tomorrow,
  }) async {
    if (!_settings.dateBefore) return;

    final datePlan = schedules.where((s) => s.isDate && s.date == tomorrow).toList();

    for (final schedule in datePlan) {
      await showLocalNotification(
        id: 2000 + tomorrow.day,
        title: '💕 내일 데이트',
        body: '내일 ${tomorrow.month}월 ${tomorrow.day}일 데이트 예정이에요!',
        type: NotificationType.dateBefore,
      );
      addToHistory(AppNotification.fromRealtime(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '💕 내일 데이트',
        body: '내일 ${tomorrow.month}월 ${tomorrow.day}일 데이트 예정이에요!',
        type: NotificationType.dateBefore,
      ));
    }
  }

  Future<void> checkDateToday({
    required List<Schedule> schedules,
    required DateTime today,
  }) async {
    if (!_settings.dateToday) return;

    final datePlan = schedules.where((s) => s.isDate && s.date == today).toList();

    for (final schedule in datePlan) {
      await showLocalNotification(
        id: 3000 + today.day,
        title: '💕 오늘 데이트',
        body: '오늘 ${today.month}월 ${today.day}일 데이트 날이에요!',
        type: NotificationType.dateToday,
      );
      addToHistory(AppNotification.fromRealtime(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '💕 오늘 데이트',
        body: '오늘 ${today.month}월 ${today.day}일 데이트 날이에요!',
        type: NotificationType.dateToday,
      ));
    }
  }
}

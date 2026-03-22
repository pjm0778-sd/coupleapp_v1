import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../features/notifications/models/notification.dart';
import '../features/notifications/models/notification_settings.dart';
import '../features/profile/models/shift_time.dart';
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
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
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

    final todayDateOnly = DateTime(today.year, today.month, today.day);
    if (commonOffDates.any((d) =>
        d.year == todayDateOnly.year &&
        d.month == todayDateOnly.month &&
        d.day == todayDateOnly.day)) {
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
        .where((s) =>
            s.isDate &&
            s.date.year == tomorrow.year &&
            s.date.month == tomorrow.month &&
            s.date.day == tomorrow.day)
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
        .where((s) =>
            s.isDate &&
            s.date.year == today.year &&
            s.date.month == today.month &&
            s.date.day == today.day)
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

  // ---------------------------------------------------------------------------
  // 파트너 출퇴근 알림 스케줄링
  // ---------------------------------------------------------------------------
  /// 파트너 출퇴근 시간에 맞춰 매일 반복 로컬 알림 예약
  /// 파트너 프로필 로드 후 호출. 기존 출퇴근 알림은 먼저 취소됨.
  Future<void> schedulePartnerCommuteAlerts({
    required String partnerName,
    required List<ShiftTime> shiftTimes,
  }) async {
    if (kIsWeb) return;
    if (!_settings.partnerCommuteAlerts) return;

    // 기존 출퇴근 알림 취소 (id 범위: 9000~9999)
    for (int i = 9000; i < 9000 + 50; i++) {
      await _plugin.cancel(i);
    }

    if (shiftTimes.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'couple_commute_channel',
      '파트너 출퇴근 알림',
      channelDescription: '파트너의 출퇴근 시간 알림',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    int idCounter = 9000;
    for (final shift in shiftTimes) {
      final label = shift.label.isNotEmpty ? shift.label : '근무';

      // 출근 알림
      await _scheduleDaily(
        id: idCounter++,
        title: '☀️ $partnerName 출근했어요',
        body: '$label 시작 (${_fmt(shift.startHour, shift.startMinute)})',
        hour: shift.startHour,
        minute: shift.startMinute,
        details: details,
      );

      // 퇴근 알림
      await _scheduleDaily(
        id: idCounter++,
        title: '🏠 $partnerName 퇴근했어요',
        body: '$label 종료 (${_fmt(shift.endHour, shift.endMinute)})',
        hour: shift.isNextDay ? shift.endHour : shift.endHour,
        minute: shift.endMinute,
        details: details,
      );
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required NotificationDetails details,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  /// 파트너 출퇴근 알림 전체 취소
  Future<void> cancelPartnerCommuteAlerts() async {
    if (kIsWeb) return;
    for (int i = 9000; i < 9100; i++) {
      await _plugin.cancel(i);
    }
  }

  /// 파트너의 '출근' 카테고리 일정 기반 출퇴근 알림 예약 (1회성)
  Future<void> scheduleCommuteFromSchedules({
    required String partnerName,
    required List<Map<String, dynamic>> scheduleRows,
  }) async {
    if (kIsWeb) return;

    // 기존 출퇴근 알림 전체 취소
    for (int i = 9000; i < 9100; i++) {
      await _plugin.cancel(i);
    }

    if (!_settings.partnerCommuteAlerts) return;
    if (scheduleRows.isEmpty) return;

    const androidDetails = AndroidNotificationDetails(
      'couple_commute_channel',
      '파트너 출퇴근 알림',
      channelDescription: '파트너의 출퇴근 시간 알림',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

    final now = tz.TZDateTime.now(tz.local);
    int idCounter = 9000;

    for (final row in scheduleRows) {
      if (idCounter >= 9100) break;

      final dateStr = row['date'] as String?;
      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr);
      final startTimeStr = row['start_time'] as String?;
      final endTimeStr = row['end_time'] as String?;

      // 출근 알림
      if (startTimeStr != null) {
        final parts = startTimeStr.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        final scheduled = tz.TZDateTime(tz.local, date.year, date.month, date.day, h, m);
        if (scheduled.isAfter(now)) {
          await _plugin.zonedSchedule(
            idCounter,
            '☀️ $partnerName 출근했어요',
            '${_fmt(h, m)} 출근 시작',
            scheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
        idCounter++;
      }

      // 퇴근 알림
      if (endTimeStr != null && idCounter < 9100) {
        final parts = endTimeStr.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        // 야간근무: 종료시간이 시작시간보다 작으면 다음날
        int dayOffset = 0;
        if (startTimeStr != null) {
          final sh = int.tryParse(startTimeStr.split(':')[0]) ?? 0;
          if (h < sh) dayOffset = 1;
        }
        final endDate = date.add(Duration(days: dayOffset));
        final scheduled = tz.TZDateTime(
            tz.local, endDate.year, endDate.month, endDate.day, h, m);
        if (scheduled.isAfter(now)) {
          await _plugin.zonedSchedule(
            idCounter,
            '🏠 $partnerName 퇴근했어요',
            '${_fmt(h, m)} 퇴근',
            scheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
        idCounter++;
      }
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

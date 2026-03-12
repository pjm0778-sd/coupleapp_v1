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

  // Web 沅뚰븳 (Web ?꾩슜)
  bool _webPermissionGranted = false;
  bool get webPermissionGranted => _webPermissionGranted;

  Stream<List<AppNotification>> get historyStream {
    _historyController ??=
        StreamController<List<AppNotification>>.broadcast();
    return _historyController!.stream;
  }

  // ????????????????????????????????????????????????
  // 珥덇린??  // ????????????????????????????????????????????????
  Future<void> initialize() async {
    await _loadSettings();

    if (kIsWeb) return; // Web? ?쒖뒪???뚮┝ 誘몄???
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
        // ?뚮┝ ???몃뱾??(?꾩슂 ???뺤옣)
      },
    );
  }

  // ????????????????????????????????????????????????
  // 沅뚰븳 ?붿껌
  // ????????????????????????????????????????????????

  /// Android 13+ / iOS ?뚮┝ 沅뚰븳 ?붿껌. true = ?덉슜??  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  // Web??(湲곗〈 ?명꽣?섏씠???명솚)
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

  // ????????????????????????????????????????????????
  // ?뚮┝ 諛쒖넚
  // ????????????????????????????????????????????????
  Future<void> showLocalNotification({
    required int id,
    required String title,
    String? body,
    NotificationType? type,
  }) async {
    // ?????덉뒪?좊━??異붽?
    if (type != null) {
      addToHistory(AppNotification.fromRealtime(
        id: '${id}_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        type: type,
      ));
    }

    if (kIsWeb) return; // Web? ?쒖뒪???뚮┝ 誘몄???
    const androidDetails = AndroidNotificationDetails(
      'couple_app_channel',
      '而ㅽ뵆 ???뚮┝',
      channelDescription: '而ㅽ뵆 ?깆쓽 ?쇱젙 諛??뚮┝',
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

  // ????????????????????????????????????????????????
  // ?덉뒪?좊━ 愿由?  // ????????????????????????????????????????????????
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

  // ????????????????????????????????????????????????
  // ?ㅼ젙 ???濡쒕뱶 (SharedPreferences)
  // ????????????????????????????????????????????????
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

  // ????????????????????????????????????????????????
  // ?ㅼ?以?湲곕컲 ?뚮┝ 泥댄겕
  // ????????????????????????????????????????????????
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
        title: '?뮇 ?????щ뒗 ??',
        body: '?ㅻ뒛 ?????대Т?ㅼ슂 ?곗씠???섏떆寃좎뼱??',
        type: NotificationType.bothOff,
      );
    }
  }

  Future<void> checkDateBefore({
    required List<Schedule> schedules,
    required DateTime tomorrow,
  }) async {
    if (!_settings.dateBefore) return;

    final datePlan =
        schedules.where((s) => s.isDate && s.date == tomorrow).toList();

    if (datePlan.isNotEmpty) {
      await showLocalNotification(
        id: 2000 + tomorrow.day,
        title: '?뮆 ?댁씪 ?곗씠??,
        body: '?댁씪 ${tomorrow.month}??${tomorrow.day}???곗씠???덉젙?댁뿉??',
        type: NotificationType.dateBefore,
      );
    }
  }

  Future<void> checkDateToday({
    required List<Schedule> schedules,
    required DateTime today,
  }) async {
    if (!_settings.dateToday) return;

    final datePlan =
        schedules.where((s) => s.isDate && s.date == today).toList();

    if (datePlan.isNotEmpty) {
      await showLocalNotification(
        id: 3000 + today.day,
        title: '?뮆 ?ㅻ뒛 ?곗씠??,
        body: '?ㅻ뒛 ${today.month}??${today.day}???곗씠???좎씠?먯슂!',
        type: NotificationType.dateToday,
      );
    }
  }

  /// ?뚰듃???쇱젙 蹂寃??뚮┝ (?쇱젙 異붽?/?섏젙/??젣 ???몄텧)
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
      NotificationType.scheduleAdded => '異붽??덉뼱??,
      NotificationType.scheduleDeleted => '??젣?덉뼱??,
      NotificationType.scheduleUpdated => '?섏젙?덉뼱??,
      _ => '蹂寃쏀뻽?댁슂',
    };

    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '?뱟 ?뚰듃???쇱젙 ?뚮┝',
      body: '?뚰듃?덇? "$scheduleTitle" ?쇱젙??$actionLabel',
      type: type,
    );
  }
}

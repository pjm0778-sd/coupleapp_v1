import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/notification_manager.dart';
import '../../../core/supabase_client.dart';
import '../models/notification.dart';
import '../models/notification_settings.dart';

class NotificationService {
  final NotificationManager _manager = NotificationManager();
  RealtimeChannel? _schedulesChannel;

  NotificationSettings get settings => _manager.settings;
  void updateSettings(NotificationSettings newSettings) => _manager.updateSettings(newSettings);
  List<AppNotification> get history => _manager.history;
  Stream<List<AppNotification>> get historyStream => _manager.historyStream;

  Future<void> initialize() async {
    await _manager.initialize();
    await _subscribeToSchedules();
  }

  Future<void> _subscribeToSchedules() async {
    final coupleId = await _getCoupleId();
    if (coupleId == null) return;

    final myUserId = supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    // ?뚰듃?덉쓽 ?쇱젙留??섏떊?섍린 ?꾪븳 ?꾪꽣??RLS濡?泥섎━
    _schedulesChannel = supabase.channel('public:schedules');

    // Subscribe to INSERT events
    _schedulesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'schedules',
      callback: (payload) async {
        final record = payload.newRecord as Map<String, dynamic>?;
        if (record == null) return;

        final userId = record['user_id'] as String?;
        // ???쇱젙? 臾댁떆 (?뚰듃?덉쓽 ?쇱젙留??뚮┝)
        if (userId == myUserId) return;

        if (_manager.settings.scheduleAdded) {
          final date = DateTime.parse(record['date'] as String);
          await _manager.showLocalNotification(
            id: DateTime.now().millisecondsSinceEpoch,
            title: '?뱟 ?뚰듃?덇? ?쇱젙??異붽??덉뼱??,
            body: '${date.month}??${date.day}???쇱젙??異붽??섏뿀?댁슂',
            type: NotificationType.scheduleAdded,
          );
          _manager.addToHistory(AppNotification.fromRealtime(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '?뱟 ?뚰듃?덇? ?쇱젙??異붽??덉뼱??,
            body: '${date.month}??${date.day}???쇱젙??異붽??섏뿀?댁슂',
            type: NotificationType.scheduleAdded,
          ));
        }
      },
    ).subscribe();

    // Subscribe to DELETE events
    _schedulesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'schedules',
      callback: (payload) async {
        final oldRecord = payload.oldRecord as Map<String, dynamic>?;
        if (oldRecord == null) return;

        final userId = oldRecord['user_id'] as String?;
        if (userId == myUserId) return;

        if (_manager.settings.scheduleDeleted) {
          final date = DateTime.parse(oldRecord['date'] as String);
          await _manager.showLocalNotification(
            id: DateTime.now().millisecondsSinceEpoch + 1,
            title: '?뿊截??뚰듃?덇? ?쇱젙????젣?덉뼱??,
            body: '${date.month}??${date.day}???쇱젙????젣?섏뿀?댁슂',
            type: NotificationType.scheduleDeleted,
          );
          _manager.addToHistory(AppNotification.fromRealtime(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '?뿊截??뚰듃?덇? ?쇱젙????젣?덉뼱??,
            body: '${date.month}??${date.day}???쇱젙????젣?섏뿀?댁슂',
            type: NotificationType.scheduleDeleted,
          ));
        }
      },
    ).subscribe();

    // Subscribe to UPDATE events
    _schedulesChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'schedules',
      callback: (payload) async {
        final oldRecord = payload.oldRecord as Map<String, dynamic>?;
        final newRecord = payload.newRecord as Map<String, dynamic>?;

        if (oldRecord == null || newRecord == null) return;

        final userId = newRecord['user_id'] as String?;
        if (userId == myUserId) return;

        if (_manager.settings.scheduleUpdated) {
          final date = DateTime.parse(newRecord['date'] as String);
          await _manager.showLocalNotification(
            id: DateTime.now().millisecondsSinceEpoch + 2,
            title: '?륅툘 ?뚰듃?덇? ?쇱젙???섏젙?덉뼱??,
            body: '${date.month}??${date.day}???쇱젙???섏젙?섏뿀?댁슂',
            type: NotificationType.scheduleUpdated,
          );
          _manager.addToHistory(AppNotification.fromRealtime(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '?륅툘 ?뚰듃?덇? ?쇱젙???섏젙?덉뼱??,
            body: '${date.month}??${date.day}???쇱젙???섏젙?섏뿀?댁슂',
            type: NotificationType.scheduleUpdated,
          ));
        }
      },
    ).subscribe();
  }

  Future<String?> _getCoupleId() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .maybeSingle();

    return profile?['couple_id'] as String?;
  }

  void dispose() {
    _schedulesChannel?.unsubscribe();
  }
}

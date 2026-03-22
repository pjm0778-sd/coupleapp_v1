import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/notification_manager.dart';
import '../../../core/supabase_client.dart';
import '../models/notification.dart';
import '../models/notification_settings.dart';
import '../../profile/models/shift_time.dart';

class NotificationService {
  final NotificationManager _manager = NotificationManager();
  RealtimeChannel? _schedulesChannel;
  RealtimeChannel? _commentsChannel;

  NotificationSettings get settings => _manager.settings;
  void updateSettings(NotificationSettings newSettings) =>
      _manager.updateSettings(newSettings);
  List<AppNotification> get history => _manager.history;
  Stream<List<AppNotification>> get historyStream => _manager.historyStream;

  Future<void> initialize() async {
    await _manager.initialize();
    await _subscribeToSchedules();
    await _subscribeToComments();
    await _schedulePartnerCommuteAlerts();
  }

  Future<void> _subscribeToSchedules() async {
    final coupleId = await _getCoupleId();
    if (coupleId == null) return;

    final myUserId = supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    // 파트너의 일정만 수신하기 위한 필터는 RLS로 처리
    _schedulesChannel = supabase.channel('public:schedules');

    // Subscribe to INSERT events
    _schedulesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'schedules',
          callback: (payload) async {
            final record = payload.newRecord as Map<String, dynamic>?;
            if (record == null) return;

            final userId = record['user_id'] as String?;
            // 내 일정은 무시 (파트너의 일정만 알림)
            if (userId == myUserId) return;

            if (_manager.settings.scheduleAdded) {
              final date = DateTime.parse(record['date'] as String);
              await _manager.showLocalNotification(
                id: DateTime.now().millisecondsSinceEpoch,
                title: '✨ 파트너가 일정을 추가했어요',
                body: '${date.month}월 ${date.day}일 일정이 추가되었어요',
                type: NotificationType.scheduleAdded,
              );
              _manager.addToHistory(
                AppNotification.fromRealtime(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: '✨ 파트너가 일정을 추가했어요',
                  body: '${date.month}월 ${date.day}일 일정이 추가되었어요',
                  type: NotificationType.scheduleAdded,
                ),
              );
            }
          },
        )
        .subscribe();

    // Subscribe to DELETE events
    _schedulesChannel!
        .onPostgresChanges(
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
                title: '🗑️ 파트너가 일정을 삭제했어요',
                body: '${date.month}월 ${date.day}일 일정이 삭제되었어요',
                type: NotificationType.scheduleDeleted,
              );
              _manager.addToHistory(
                AppNotification.fromRealtime(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: '🗑️ 파트너가 일정을 삭제했어요',
                  body: '${date.month}월 ${date.day}일 일정이 삭제되었어요',
                  type: NotificationType.scheduleDeleted,
                ),
              );
            }
          },
        )
        .subscribe();

    // Subscribe to UPDATE events
    _schedulesChannel!
        .onPostgresChanges(
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
                title: '📝 파트너가 일정을 수정했어요',
                body: '${date.month}월 ${date.day}일 일정이 수정되었어요',
                type: NotificationType.scheduleUpdated,
              );
              _manager.addToHistory(
                AppNotification.fromRealtime(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: '📝 파트너가 일정을 수정했어요',
                  body: '${date.month}월 ${date.day}일 일정이 수정되었어요',
                  type: NotificationType.scheduleUpdated,
                ),
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> _subscribeToComments() async {
    final myUserId = supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    _commentsChannel = supabase.channel('public:schedule_comments');

    _commentsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'schedule_comments',
          callback: (payload) async {
            final record = payload.newRecord as Map<String, dynamic>?;
            if (record == null) return;

            final userId = record['user_id'] as String?;
            // 내 댓글은 무시
            if (userId == myUserId) return;

            if (_manager.settings.commentAdded) {
              // 일정 제목을 가져오기 위해 조회
              final scheduleId = record['schedule_id'] as String;
              final schedule = await supabase
                  .from('schedules')
                  .select('title, work_type')
                  .eq('id', scheduleId)
                  .maybeSingle();

              final scheduleTitle =
                  schedule?['title'] ?? schedule?['work_type'] ?? '일정';

              await _manager.showLocalNotification(
                id: DateTime.now().millisecondsSinceEpoch,
                title: '💬 파트너가 댓글을 남겼어요',
                body: '"$scheduleTitle" 일정에 댓글이 달렸습니다',
                type: NotificationType.commentAdded,
              );
              _manager.addToHistory(
                AppNotification.fromRealtime(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: '💬 파트너가 댓글을 남겼어요',
                  body: '"$scheduleTitle" 일정에 댓글이 달렸습니다',
                  type: NotificationType.commentAdded,
                ),
              );
            }
          },
        )
        .subscribe();
  }

  /// 파트너 출퇴근 알림 스케줄링 (외부 호출 가능)
  Future<void> scheduleCommuteAlertsForPartner() =>
      _schedulePartnerCommuteAlerts();

  /// 파트너 출퇴근 알림 스케줄링
  /// 파트너 프로필의 shiftTimes를 읽어 매일 반복 로컬 알림 예약
  Future<void> _schedulePartnerCommuteAlerts() async {
    final myUserId = supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    final coupleId = await _getCoupleId();
    if (coupleId == null) return;

    final coupleData = await supabase
        .from('couples')
        .select('user1_id, user2_id')
        .eq('id', coupleId)
        .maybeSingle();
    if (coupleData == null) return;

    final partnerId = coupleData['user1_id'] == myUserId
        ? coupleData['user2_id'] as String?
        : coupleData['user1_id'] as String?;
    if (partnerId == null) return;

    final partnerData = await supabase
        .from('profiles')
        .select('nickname, shift_times')
        .eq('id', partnerId)
        .maybeSingle();
    if (partnerData == null) return;

    final partnerName = partnerData['nickname'] as String? ?? '파트너';
    final rawShifts = partnerData['shift_times'];
    final shiftTimes = rawShifts is List
        ? rawShifts.cast<Map<String, dynamic>>().map(ShiftTime.fromMap).toList()
        : <ShiftTime>[];

    await _manager.schedulePartnerCommuteAlerts(
      partnerName: partnerName,
      shiftTimes: shiftTimes,
    );
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
    _commentsChannel?.unsubscribe();
  }
}

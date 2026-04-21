import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/notification_manager.dart';
import '../../../core/supabase_client.dart';
import '../models/notification.dart';
import '../models/notification_settings.dart';

class NotificationService {
  final NotificationManager _manager = NotificationManager();
  RealtimeChannel? _schedulesChannel;
  RealtimeChannel? _commentsChannel;
  bool _isInitialized = false;

  NotificationSettings get settings => _manager.settings;
  void updateSettings(NotificationSettings newSettings) =>
      _manager.updateSettings(newSettings);
  List<AppNotification> get history => _manager.history;
  Stream<List<AppNotification>> get historyStream => _manager.historyStream;

  // ── 일괄 알림 디바운스 상태 ─────────────────────────────
  // INSERT 디바운스
  Timer? _insertDebounceTimer;
  int _pendingInsertCount = 0;
  final Set<String> _pendingInsertMonths = {}; // "YYYY-M"
  bool _pendingInsertHasCommute = false;

  // DELETE 디바운스
  Timer? _deleteDebounceTimer;
  int _pendingDeleteCount = 0;
  final Set<String> _pendingDeleteMonths = {};
  bool _pendingDeleteHasCommute = false;

  // 파트너 닉네임 캐시
  String? _cachedPartnerName;

  static const _debounceMs = 3000; // 3초

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _manager.initialize();
    await _subscribeToSchedules();
    await _subscribeToComments();
    await _schedulePartnerCommuteAlerts();
    _isInitialized = true;
  }

  Future<void> _subscribeToSchedules() async {
    if (_schedulesChannel != null) return;

    final coupleId = await _getCoupleId();
    if (coupleId == null) return;

    final myUserId = supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    _schedulesChannel = supabase.channel('public:schedules');

    // ── INSERT ───────────────────────────────────────────
    _schedulesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'schedules',
          callback: (payload) {
            final record = payload.newRecord as Map<String, dynamic>?;
            if (record == null) return;
            final userId = record['user_id'] as String?;
            if (userId == myUserId) return; // 내 일정 무시

            // 디바운스 상태 누적
            _insertDebounceTimer?.cancel();
            _pendingInsertCount++;
            try {
              final date = DateTime.parse(record['date'] as String);
              _pendingInsertMonths
                  .add('${date.year}-${date.month}');
            } catch (_) {}
            if (record['category'] == '출근') {
              _pendingInsertHasCommute = true;
            }

            // 3초 후 통합 알림 발송
            _insertDebounceTimer =
                Timer(const Duration(milliseconds: _debounceMs), () async {
              if (!_manager.settings.scheduleAdded) {
                _resetInsertState();
                return;
              }
              final count = _pendingInsertCount;
              final months = Set<String>.from(_pendingInsertMonths);
              final hasCommute = _pendingInsertHasCommute;
              _resetInsertState();

              final (title, body) =
                  await _buildInsertMessage(count, months);

              await _manager.showLocalNotification(
                id: DateTime.now().millisecondsSinceEpoch,
                title: title,
                body: body,
                type: NotificationType.scheduleAdded,
              );
              if (hasCommute) _schedulePartnerCommuteAlerts();
            });
          },
        );

    // ── DELETE ───────────────────────────────────────────
    _schedulesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'schedules',
          callback: (payload) {
            final oldRecord = payload.oldRecord as Map<String, dynamic>?;
            if (oldRecord == null) return;
            final userId = oldRecord['user_id'] as String?;
            if (userId == myUserId) return;

            _deleteDebounceTimer?.cancel();
            _pendingDeleteCount++;
            try {
              final date = DateTime.parse(oldRecord['date'] as String);
              _pendingDeleteMonths
                  .add('${date.year}-${date.month}');
            } catch (_) {}
            if (oldRecord['category'] == '출근') {
              _pendingDeleteHasCommute = true;
            }

            _deleteDebounceTimer =
                Timer(const Duration(milliseconds: _debounceMs), () async {
              if (!_manager.settings.scheduleDeleted) {
                _resetDeleteState();
                return;
              }
              final count = _pendingDeleteCount;
              final months = Set<String>.from(_pendingDeleteMonths);
              final hasCommute = _pendingDeleteHasCommute;
              _resetDeleteState();

              final (title, body) =
                  await _buildDeleteMessage(count, months);

              await _manager.showLocalNotification(
                id: DateTime.now().millisecondsSinceEpoch + 1,
                title: title,
                body: body,
                type: NotificationType.scheduleDeleted,
              );
              if (hasCommute) _schedulePartnerCommuteAlerts();
            });
          },
        );

    // ── UPDATE (단건 — 디바운스 불필요) ──────────────────
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
            }
            if (newRecord['category'] == '출근' ||
                oldRecord['category'] == '출근') {
              _schedulePartnerCommuteAlerts();
            }
          },
        )
        .subscribe();
  }

  // ── 메시지 생성 ──────────────────────────────────────────

  Future<(String, String)> _buildInsertMessage(
      int count, Set<String> months) async {
    if (count == 1) {
      final m = _parseMonth(months.first);
      return (
        '✨ 파트너가 일정을 추가했어요',
        '$m월 일정이 추가되었어요',
      );
    }
    final partnerName = await _getPartnerName() ?? '파트너';
    if (months.length == 1) {
      final m = _parseMonth(months.first);
      return (
        '📅 근무표가 기입되었어요',
        '$partnerName님이 $m월 근무표를 자동 기입하였습니다 ($count개)',
      );
    }
    final monthList =
        months.map(_parseMonth).toList()..sort();
    final monthStr = monthList.map((m) => '$m월').join(', ');
    return (
      '📅 근무표가 기입되었어요',
      '$partnerName님이 $monthStr 근무표를 자동 기입하였습니다 ($count개)',
    );
  }

  Future<(String, String)> _buildDeleteMessage(
      int count, Set<String> months) async {
    if (count == 1) {
      final m = _parseMonth(months.first);
      return (
        '🗑️ 파트너가 일정을 삭제했어요',
        '$m월 일정이 삭제되었어요',
      );
    }
    final partnerName = await _getPartnerName() ?? '파트너';
    if (months.length == 1) {
      final m = _parseMonth(months.first);
      return (
        '🗑️ 일정이 삭제되었어요',
        '$partnerName님이 $m월 근무표를 삭제하였습니다 ($count개)',
      );
    }
    final monthList =
        months.map(_parseMonth).toList()..sort();
    final monthStr = monthList.map((m) => '$m월').join(', ');
    return (
      '🗑️ 일정이 삭제되었어요',
      '$partnerName님이 $monthStr 일정을 삭제하였습니다 ($count개)',
    );
  }

  int _parseMonth(String yearMonth) {
    // "YYYY-M" 형식
    final parts = yearMonth.split('-');
    return parts.length >= 2 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }

  // ── 상태 초기화 ──────────────────────────────────────────

  void _resetInsertState() {
    _pendingInsertCount = 0;
    _pendingInsertMonths.clear();
    _pendingInsertHasCommute = false;
  }

  void _resetDeleteState() {
    _pendingDeleteCount = 0;
    _pendingDeleteMonths.clear();
    _pendingDeleteHasCommute = false;
  }

  // ── 댓글 구독 ────────────────────────────────────────────

  Future<void> _subscribeToComments() async {
    if (_commentsChannel != null) return;

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
            if (userId == myUserId) return;

            if (_manager.settings.commentAdded) {
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
            }
          },
        )
        .subscribe();
  }

  // ── 파트너 출퇴근 알림 스케줄링 ──────────────────────────

  Future<void> scheduleCommuteAlertsForPartner() =>
      _schedulePartnerCommuteAlerts();

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
        .select('nickname')
        .eq('id', partnerId)
        .maybeSingle();
    if (partnerData == null) return;

    final partnerName = partnerData['nickname'] as String? ?? '파트너';
    _cachedPartnerName = partnerName; // 캐시 갱신

    final today = DateTime.now();
    final until = today.add(const Duration(days: 14));
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final untilStr =
        '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}';

    final rows = await supabase
        .from('schedules')
        .select('date, start_time, end_time')
        .eq('user_id', partnerId)
        .eq('category', '출근')
        .gte('date', todayStr)
        .lte('date', untilStr)
        .order('date');

    await _manager.scheduleCommuteFromSchedules(
      partnerName: partnerName,
      scheduleRows: (rows as List).cast<Map<String, dynamic>>(),
    );
  }

  // ── 파트너 닉네임 조회 (캐시 우선) ──────────────────────

  Future<String?> _getPartnerName() async {
    if (_cachedPartnerName != null) return _cachedPartnerName;
    final myUserId = supabase.auth.currentUser?.id;
    if (myUserId == null) return null;
    final coupleId = await _getCoupleId();
    if (coupleId == null) return null;
    final couple = await supabase
        .from('couples')
        .select('user1_id, user2_id')
        .eq('id', coupleId)
        .maybeSingle();
    if (couple == null) return null;
    final partnerId = couple['user1_id'] == myUserId
        ? couple['user2_id'] as String?
        : couple['user1_id'] as String?;
    if (partnerId == null) return null;
    final profile = await supabase
        .from('profiles')
        .select('nickname')
        .eq('id', partnerId)
        .maybeSingle();
    _cachedPartnerName = profile?['nickname'] as String?;
    return _cachedPartnerName;
  }

  // ── 공통 유틸 ────────────────────────────────────────────

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
    _insertDebounceTimer?.cancel();
    _deleteDebounceTimer?.cancel();
    _schedulesChannel?.unsubscribe();
    _commentsChannel?.unsubscribe();
    _schedulesChannel = null;
    _commentsChannel = null;
    _isInitialized = false;
  }
}

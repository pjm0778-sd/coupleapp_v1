import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../../../core/holiday_service.dart';
import '../../../shared/models/schedule.dart';
import '../services/home_service.dart';
import '../widgets/dday_widget.dart';
import '../widgets/next_date_widget.dart';
import '../widgets/today_schedule_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();

  Map<String, dynamic> _data = {};
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  RealtimeChannel? _schedulesChannel;
  RealtimeChannel? _couplesChannel;

  String? _coupleId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 다른 탭(설정 등)에서 돌아올 때 데이터 갱신
    if (_hasLoadedOnce) {
      _loadData();
    }
    _hasLoadedOnce = true;
  }

  void _setupRealtime() {
    if (_coupleId == null) return;

    _schedulesChannel ??= supabase.channel('public:schedules')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'schedules',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'couple_id',
          value: _coupleId!,
        ),
        callback: (payload) {
          if (mounted) _loadData();
        },
      )..subscribe();

    _couplesChannel ??= supabase.channel('public:couples_home')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'couples',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: _coupleId!,
        ),
        callback: (payload) {
          if (mounted) _loadData();
        },
      )..subscribe();
  }

  @override
  void dispose() {
    _schedulesChannel?.unsubscribe();
    _couplesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    _coupleId = await _homeService.getCoupleId();
    if (_coupleId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final summary = await _homeService.getHomeSummary(_coupleId!);
      if (mounted) {
        setState(() {
          _data = summary;
          _isLoading = false;
        });
        _setupRealtime();
        // 데이줌 알림 자동 체크
        _checkNotifications(summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkNotifications(Map<String, dynamic> data) async {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final nm = NotificationManager();

    // 오늘 데이트 체크
    final todaySchedules = data['today_schedules'] as Map<String, List<Schedule>>?;
    if (todaySchedules != null) {
      final allToday = <Schedule>[
        ...(todaySchedules['mine'] ?? []),
        ...(todaySchedules['partner'] ?? []),
      ];
      await nm.checkDateToday(schedules: allToday, today: today);

      // 불무 체크
      final myOff = (todaySchedules['mine'] ?? []).where((s) => s.category == '휴무').toList();
      final partnerOff = (todaySchedules['partner'] ?? []).where((s) => s.category == '휴무').toList();
      if (myOff.isNotEmpty && partnerOff.isNotEmpty) {
        await nm.checkBothOffAndSchedule(
          mySchedules: myOff,
          partnerSchedules: partnerOff,
          today: today,
        );
      }
    }

    // 내일 데이트 체크
    final tomorrowSchedules = data['tomorrow_schedules'] as Map<String, List<Schedule>>?;
    if (tomorrowSchedules != null) {
      final allTomorrow = <Schedule>[
        ...(tomorrowSchedules['mine'] ?? []),
        ...(tomorrowSchedules['partner'] ?? []),
      ];
      await nm.checkDateBefore(schedules: allTomorrow, tomorrow: tomorrow);
    }
  }

  int? get _dDays => _data['d_days']?['days'] as int?;
  String? get _partnerNickname => _data['d_days']?['partner_nickname'] as String?;
  Map<String, List<Schedule>>? get _todaySchedules =>
      _data['today_schedules'] as Map<String, List<Schedule>>?;
  Map<String, List<Schedule>>? get _tomorrowSchedules =>
      _data['tomorrow_schedules'] as Map<String, List<Schedule>>?;
  Map<String, dynamic>? get _nextDate => _data['next_date'] as Map<String, dynamic>?;
  int? get _nextDateDaysUntil => _data['next_date']?['days_until'] as int?;

  bool _hasSchedules(Map<String, List<Schedule>>? schedules) {
    if (schedules == null) return false;
    return (schedules['mine']?.isNotEmpty ?? false) ||
        (schedules['partner']?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final todayWeekday = weekdays[today.weekday - 1];
    final tomorrowWeekday = weekdays[tomorrow.weekday - 1];
    final todayHolidays = HolidayService().getHolidays(today);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '우리의 이야기',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              todayHolidays.isNotEmpty
                  ? '${today.month}월 ${today.day}일 ($todayWeekday)  ·  ${todayHolidays.first.emoji} ${todayHolidays.first.name}'
                  : '${today.month}월 ${today.day}일 ($todayWeekday)',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupleId == null
              ? _buildNoCoupleState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildHomeContent(todayWeekday, tomorrowWeekday),
                ),
    );
  }

  Widget _buildNoCoupleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            '커플 연결이 필요합니다',
            style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(String todayWeekday, String tomorrowWeekday) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // D+day 위젯 (화면 1/6 크기, 탭 설정 없음)
          DDayWidget(
            days: _dDays,
            partnerNickname: _partnerNickname,
            nextDateDays: _nextDateDaysUntil,
          ),
          const SizedBox(height: 16),
          // 다가오는 데이트
          if (_nextDate != null) ...[
            NextDateWidget(
              nextDateSchedule: _nextDate!['schedule'] as Schedule,
              daysUntil: _nextDate!['days_until'] as int,
            ),
            const SizedBox(height: 16),
          ],
          // 오늘의 일정
          TodayScheduleWidget(
            todaySchedules: _todaySchedules ?? {},
            weekday: todayWeekday,
            title: '오늘의 일정',
          ),
          // 내일의 일정 (일정이 있을 때만 표시)
          if (_hasSchedules(_tomorrowSchedules)) ...[
            const SizedBox(height: 16),
            TodayScheduleWidget(
              todaySchedules: _tomorrowSchedules ?? {},
              weekday: tomorrowWeekday,
              title: '내일의 일정',
            ),
          ],
        ],
      ),
    );
  }
}

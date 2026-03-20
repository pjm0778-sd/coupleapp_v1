import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../../../core/holiday_service.dart';
import '../../../core/profile_change_notifier.dart';
import '../../../shared/models/schedule.dart';
import '../../profile/models/couple_profile.dart';
import '../../profile/services/profile_service.dart';
import '../services/home_service.dart';
import '../widgets/next_date_widget.dart';
import '../widgets/today_schedule_widget.dart';
import '../widgets/transport_preview_card.dart';
import '../../midpoint/screens/midpoint_search_screen.dart';
import '../../calendar/widgets/schedule_detail.dart';
import 'relationship_timeline_screen.dart';

// ─── Animated D-day Counter ──────────────────────────────────────────────────

class _AnimatedDayCounter extends StatefulWidget {
  final int days;

  const _AnimatedDayCounter({required this.days});

  @override
  State<_AnimatedDayCounter> createState() => _AnimatedDayCounterState();
}

class _AnimatedDayCounterState extends State<_AnimatedDayCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = IntTween(begin: 0, end: widget.days).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedDayCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _animation = IntTween(begin: 0, end: widget.days).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Text(
          '${_animation.value}',
          style: const TextStyle(
            fontSize: 40,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontFamily: 'PlayfairDisplay',
            height: 1.0,
          ),
        );
      },
    );
  }
}

// ─── HomeScreen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();
  final _profileService = ProfileService();

  Map<String, dynamic> _data = {};
  CoupleProfile? _profile;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  RealtimeChannel? _schedulesChannel;
  RealtimeChannel? _couplesChannel;
  StreamSubscription<void>? _profileChangeSub;

  String? _coupleId;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 설정 변경 시 자동 새로고침
    _profileChangeSub = ProfileChangeNotifier().onChange.listen((_) {
      if (mounted) _loadData();
    });
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

    // 이미 채널이 있으면 리스너만 재확인하거나 무시 (중복 방지)
    if (_schedulesChannel != null) return;

    _schedulesChannel =
        Supabase.instance.client
            .channel('public:schedules_home')
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
                debugPrint('Realtime change detected: ${payload.eventType}');
                if (mounted) _loadData();
              },
            )
          ..subscribe();

    _couplesChannel ??=
        Supabase.instance.client
            .channel('public:couples_home')
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
            )
          ..subscribe();
  }

  @override
  void dispose() {
    _schedulesChannel?.unsubscribe();
    _couplesChannel?.unsubscribe();
    _profileChangeSub?.cancel();
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
      final results = await Future.wait([
        _homeService.getHomeSummary(_coupleId!),
        _profileService.loadMyProfile(),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0] as Map<String, dynamic>;
          _profile = results[1] as CoupleProfile?;
          _isLoading = false;
        });
        _setupRealtime();
        // 데이트 알림 자동 체크
        _checkNotifications(_data);
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
    final todaySchedules =
        data['today_schedules'] as Map<String, List<Schedule>>?;
    if (todaySchedules != null) {
      final allToday = <Schedule>[
        ...(todaySchedules['mine'] ?? []),
        ...(todaySchedules['partner'] ?? []),
      ];
      await nm.checkDateToday(schedules: allToday, today: today);

      // 둘 다 휴무 체크
      final myOff = (todaySchedules['mine'] ?? [])
          .where((s) => s.category == '휴무')
          .toList();
      final partnerOff = (todaySchedules['partner'] ?? [])
          .where((s) => s.category == '휴무')
          .toList();
      if (myOff.isNotEmpty && partnerOff.isNotEmpty) {
        await nm.checkBothOffAndSchedule(
          mySchedules: myOff,
          partnerSchedules: partnerOff,
          today: today,
        );
      }
    }

    // 내일 데이트 체크
    final tomorrowSchedules =
        data['tomorrow_schedules'] as Map<String, List<Schedule>>?;
    if (tomorrowSchedules != null) {
      final allTomorrow = <Schedule>[
        ...(tomorrowSchedules['mine'] ?? []),
        ...(tomorrowSchedules['partner'] ?? []),
      ];
      await nm.checkDateBefore(schedules: allTomorrow, tomorrow: tomorrow);
    }
  }

  int? get _dDays => _data['d_days']?['days'] as int?;
  String? get _partnerNickname =>
      _data['d_days']?['partner_nickname'] as String?;
  Map<String, List<Schedule>>? get _todaySchedules =>
      _data['today_schedules'] as Map<String, List<Schedule>>?;
  Map<String, List<Schedule>>? get _tomorrowSchedules =>
      _data['tomorrow_schedules'] as Map<String, List<Schedule>>?;
  Map<String, dynamic>? get _nextDate =>
      _data['next_date'] as Map<String, dynamic>?;
  int? get _nextDateDaysUntil => _data['next_date']?['days_until'] as int?;

  bool _hasSchedules(Map<String, List<Schedule>>? schedules) {
    if (schedules == null) return false;
    return (schedules['mine']?.isNotEmpty ?? false) ||
        (schedules['partner']?.isNotEmpty ?? false);
  }

  // ─── Relationship start date from data ───────────────────────────────────
  String? get _relationshipStartDate =>
      _data['d_days']?['started_at'] as String?;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final todayWeekday = weekdays[today.weekday - 1];
    final tomorrowWeekday = weekdays[tomorrow.weekday - 1];
    final todayHolidays = HolidayService().getHolidays(today);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupleId == null
          ? _buildNoCoupleState()
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: _buildHomeContent(
                  today, todayWeekday, tomorrowWeekday, todayHolidays,
                ),
              ),
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
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
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

  Widget _buildHomeContent(
    DateTime today,
    String todayWeekday,
    String tomorrowWeekday,
    List<dynamic> todayHolidays,
  ) {
    final hour = today.hour;
    final greeting = hour < 6
        ? '밤 늦게까지 함께해요 🌙'
        : hour < 12
        ? '좋은 아침이에요 ☀️'
        : hour < 17
        ? '좋은 오후예요 🌤️'
        : '좋은 저녁이에요 🌆';
    final partnerName = _partnerNickname ?? '애인';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '${today.month}월 ${today.day}일 ($todayWeekday)',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (todayHolidays.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              todayHolidays.first.name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: AppTheme.textTertiary,
                ),
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadData();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Bento Box Grid ─────────────────────────
          if (_dDays != null) ...[
            _buildBentoGrid(partnerName, todayWeekday),
            const SizedBox(height: 20),
          ],

          // ── 내일의 일정 (full width) ────────────────
          if (_hasSchedules(_tomorrowSchedules)) ...[
            TodayScheduleWidget(
              todaySchedules: _tomorrowSchedules ?? {},
              weekday: tomorrowWeekday,
              title: '내일의 일정',
              partnerNickname: _partnerNickname,
              onScheduleTap: (s) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ScheduleDetailScreen(schedule: s),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── 교통편 카드 ─────────────────────────────
          if (_profile?.hasTransportInfo == true) ...[
            TransportPreviewCard(
              fromStation: _profile!.myStation!,
              toStation: _profile!.partnerStation!,
              nextDate: _nextDate != null
                  ? (_nextDate!['schedule'] as Schedule).date
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // ── 중간지점 찾기 배너 ──────────────────────
          _MidpointBanner(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const MidpointSearchScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bento Grid ────────────────────────────────────────────────────────────

  Widget _buildBentoGrid(String partnerName, String todayWeekday) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: D-day card (flex 4)
          Expanded(
            flex: 4,
            child: _buildDDayCard(partnerName),
          ),
          const SizedBox(width: 12),
          // Right column (flex 5): today schedule + next date stacked
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Today schedule mini card
                Expanded(
                  child: _buildTodayScheduleMini(todayWeekday),
                ),
                const SizedBox(height: 10),
                // Next date mini card
                _buildNextDateMini(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDDayCard(String partnerName) {
    // Format relationship start date
    String startDateLabel = '';
    if (_relationshipStartDate != null) {
      try {
        final dt = DateTime.parse(_relationshipStartDate!);
        startDateLabel = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        startDateLabel = _relationshipStartDate!;
      }
    }

    return GestureDetector(
      onTap: () {
        DateTime? startedAt;
        if (_relationshipStartDate != null) {
          try {
            startedAt = DateTime.parse(_relationshipStartDate!);
          } catch (_) {}
        }
        if (startedAt == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RelationshipTimelineScreen(
              startedAt: startedAt!,
              myNickname: null,
              partnerNickname: _partnerNickname,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D5E58), Color(0xFF3D7068)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [AppTheme.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Partner name label
            Text(
              '$partnerName 과 함께',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            // D+ label
            const Text(
              'D+',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            // Animated counter
            if (_dDays != null) _AnimatedDayCounter(days: _dDays!),
            const Spacer(),
            // Relationship start date
            if (startDateLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  startDateLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayScheduleMini(String todayWeekday) {
    final schedules = _todaySchedules;
    final mySchedules = schedules?['mine'] ?? [];
    final partnerSchedules = schedules?['partner'] ?? [];
    final partnerName = _partnerNickname ?? '애인';
    final hasAny = mySchedules.isNotEmpty || partnerSchedules.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 일정',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                todayWeekday,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasAny)
            const Expanded(
              child: Center(
                child: Text(
                  '일정 없음',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mySchedules.isNotEmpty) ...[
                      _buildMiniScheduleRow('나', mySchedules),
                    ],
                    if (partnerSchedules.isNotEmpty) ...[
                      if (mySchedules.isNotEmpty) const SizedBox(height: 4),
                      _buildMiniScheduleRow(partnerName, partnerSchedules),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniScheduleRow(String label, List<Schedule> schedules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        ...schedules.take(2).map((s) {
          final timeStr = s.startTime != null
              ? '${s.startTime!.substring(0, 5)} '
              : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 5, top: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    '$timeStr${s.category}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        if (schedules.length > 2)
          Text(
            '+${schedules.length - 2}개 더',
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
      ],
    );
  }

  Widget _buildNextDateMini() {
    final daysUntil = _nextDateDaysUntil;
    final nextDate = _nextDate;

    String dateLabel = '';
    if (nextDate != null) {
      try {
        final schedule = nextDate['schedule'] as Schedule;
        final dt = schedule.date;
        dateLabel = '${dt.month}월 ${dt.day}일';
      } catch (_) {}
    }

    final daysText = daysUntil == null
        ? '일정 없음'
        : daysUntil == 0
        ? '오늘!'
        : daysUntil == 1
        ? '내일!'
        : 'D-$daysUntil';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '다음 데이트',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                daysText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.0,
                ),
              ),
            ],
          ),
          if (dateLabel.isNotEmpty) ...[
            const Spacer(),
            Text(
              dateLabel,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── _MidpointBanner ─────────────────────────────────────────────────────────

class _MidpointBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _MidpointBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.accentLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('📍', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('중간지점 찾기',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text('두 사람이 공평하게 만날 수 있는 곳 추천',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

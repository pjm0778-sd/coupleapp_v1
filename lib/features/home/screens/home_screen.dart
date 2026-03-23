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
import '../widgets/weather_card.dart';
import '../widgets/longing_gauge_card.dart';
import '../services/weather_service.dart';
import '../../../core/home_widget_service.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../transport/screens/transport_search_screen.dart';
import '../../midpoint/screens/midpoint_search_screen.dart';
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
        // 홈 위젯 업데이트
        _updateHomeWidget();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateHomeWidget() async {
    final dDays       = _dDays ?? 0;
    final partnerName = _partnerNickname ?? '애인';

    // 오늘 일정 첫 번째
    final myList      = _todaySchedules?['mine']    ?? [];
    final partnerList = _todaySchedules?['partner'] ?? [];
    final mySchedule  = myList.isNotEmpty
        ? (myList.first.title ?? myList.first.category ?? '일정')
        : '여유로운 하루';
    final partnerSchedule = partnerList.isNotEmpty
        ? (partnerList.first.title ?? partnerList.first.category ?? '일정')
        : '여유로운 하루';

    // 날씨 (Medium용)
    String myWeather      = '';
    String partnerWeather = '';
    final myCity      = _profile?.myCity;
    final partnerCity = _profile?.partnerCity;
    final weatherSvc  = WeatherService();
    if (myCity != null) {
      final w = await weatherSvc.getWeather(myCity);
      if (w != null) {
        myWeather = HomeWidgetService.formatWeather(
          city: myCity, temperature: w.temperature, weatherCode: w.weatherCode,
        );
      }
    }
    if (partnerCity != null) {
      final w = await weatherSvc.getWeather(partnerCity);
      if (w != null) {
        partnerWeather = HomeWidgetService.formatWeather(
          city: partnerCity, temperature: w.temperature, weatherCode: w.weatherCode,
        );
      }
    }

    // 다음 데이트
    final nextDays  = _nextDateDaysUntil ?? -1;
    String nextLabel = '';
    if (_nextDate != null) {
      final s = _nextDate!['schedule'] as Schedule;
      nextLabel = '${s.date.month}월 ${s.date.day}일';
    }

    await HomeWidgetService.updateWidget(
      dDays:           dDays,
      partnerName:     partnerName,
      mySchedule:      mySchedule,
      partnerSchedule: partnerSchedule,
      myWeather:       myWeather,
      partnerWeather:  partnerWeather,
      nextDateDays:    nextDays,
      nextDateLabel:   nextLabel,
    );
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

  // ─── Relationship start date from data ───────────────────────────────────
  String? get _relationshipStartDate =>
      _data['d_days']?['started_at'] as String?;

  Map<String, dynamic>? get _lastDate =>
      _data['last_date'] as Map<String, dynamic>?;

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
          ? _buildSkeletonLoading()
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

  Widget _buildSkeletonLoading() {
    return const SafeArea(
      child: _HomeSkeletonLoader(),
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
            '아직 연인과 연결되지 않았어요',
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
    final tomorrow = today.add(const Duration(days: 1));
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

          // ── Bento Box Grid (오늘 + 내일 + 다음 데이트 포함) ──
          _buildBentoGrid(partnerName, today, tomorrow),
          const SizedBox(height: 20),

          // ── 보고 싶은 마음 게이지 카드 ───────────────────
          _buildLongingGaugeCard(),
          const SizedBox(height: 16),

          // ── 오늘 + 내일 일정 통합 카드 ──────────────────
          _buildScheduleCombinedCard(today, tomorrow, todayWeekday, tomorrowWeekday),
          const SizedBox(height: 16),

          // ── 날씨 카드 ────────────────────────────────
          WeatherCard(
            myCity: _profile?.myCity,
            partnerCity: _profile?.partnerCity,
            partnerNickname: _partnerNickname,
            onSetupTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bento Grid ────────────────────────────────────────────────────────────

  Widget _buildBentoGrid(
    String partnerName,
    DateTime today,
    DateTime tomorrow,
  ) {
    return SizedBox(
      height: 310,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: D-day card (flex 4)
          Expanded(
            flex: 4,
            child: _buildDDayCard(partnerName),
          ),
          const SizedBox(width: 12),
          // Right column (flex 5): 오늘 + 내일 + 다음 데이트
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(
                  child: _buildTransportMini(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildMidpointMini(),
                ),
                const SizedBox(height: 8),
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
    DateTime? startedAt;
    String startDateLabel = '';
    if (_relationshipStartDate != null) {
      try {
        startedAt = DateTime.parse(_relationshipStartDate!);
        startDateLabel =
            '${startedAt.year}.${startedAt.month.toString().padLeft(2, '0')}.${startedAt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        startDateLabel = _relationshipStartDate!;
      }
    }

    // 다음 기념일 계산
    String nextMilestoneLabel = '';
    int nextMilestoneDays = 0;
    if (_dDays != null && startedAt != null) {
      final now = DateTime.now();
      final nowDate = DateTime(now.year, now.month, now.day);

      // 다음 100일 단위
      final next100 = ((_dDays! ~/ 100) + 1) * 100;
      final daysToNext100 = next100 - _dDays!;

      // 다음 주년
      int daysToAnniv = 999999;
      String annivLabel = '';
      for (int y = 1; y <= 20; y++) {
        final anniv = DateTime(
            startedAt.year + y, startedAt.month, startedAt.day);
        if (!anniv.isBefore(nowDate)) {
          daysToAnniv = anniv.difference(nowDate).inDays;
          annivLabel = '$y주년';
          break;
        }
      }

      if (daysToAnniv < daysToNext100) {
        nextMilestoneLabel = annivLabel;
        nextMilestoneDays = daysToAnniv;
      } else {
        nextMilestoneLabel = 'D+$next100';
        nextMilestoneDays = daysToNext100;
      }
    }

    return GestureDetector(
      onTap: () {
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
            colors: [Color(0xFF1E3932), Color(0xFF00704A)],
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
            // Partner name + nav indicator
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '$partnerName 과 함께',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
            // D+ label + counter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'D+',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_dDays != null)
                  _AnimatedDayCounter(days: _dDays!)
                else
                  const Text(
                    '---',
                    style: TextStyle(
                      fontSize: 40,
                      color: Colors.white38,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
              ],
            ),
            // 다음 기념일 섹션
            if (nextMilestoneLabel.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '다음 기념일',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      nextMilestoneLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      nextMilestoneDays == 0
                          ? '오늘!'
                          : 'D-$nextMilestoneDays',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Relationship start date
            if (startDateLabel.isNotEmpty)
              Text(
                startDateLabel,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              )
            else
              const Text(
                '처음 만난 날을 알려주세요',
                style: TextStyle(fontSize: 10, color: Colors.white30),
              ),
          ],
        ),
      ),
    );
  }

  // ── 서로에게 가는 길 미니 카드 ──────────────────────────────────────────────

  Widget _buildTransportMini() {
    final fromStation = _profile?.myStation;
    final toStation = _profile?.partnerStation;
    final hasInfo = fromStation != null && toStation != null;
    final nextDate = _nextDate != null
        ? (_nextDate!['schedule'] as Schedule).date
        : null;

    return GestureDetector(
      onTap: hasInfo
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransportSearchScreen(
                    fromStation: fromStation,
                    toStation: toStation,
                    initialDate: nextDate,
                  ),
                ),
              )
          : null,
      child: Container(
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
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.train_outlined,
                    color: AppTheme.primary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '서로에게 가는 길',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasInfo)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _shortStationName(fromStation),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 10,
                          color: AppTheme.accent,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _shortStationName(toStation),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '설정에서 출발역을\n등록해 보세요',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 중간지점 찾기 미니 카드 ────────────────────────────────────────────────

  Widget _buildMidpointMini() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MidpointSearchScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1),
          boxShadow: const [AppTheme.subtleShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: AppTheme.primary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '중간지점 찾기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '우리 사이 딱\n중간 어딘가에서',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 보고 싶은 마음 게이지 카드 ──────────────────────────────────────────

  Widget _buildLongingGaugeCard() {
    final lastDate = _lastDate;
    final nextDate = _nextDate;

    // 마지막 만남 이후 일수
    int longingDays = 0;
    String lastDateLabel = '';
    if (lastDate != null) {
      longingDays = (lastDate['days_since'] as int?) ?? 0;
      final s = lastDate['schedule'] as Schedule;
      lastDateLabel = '${s.date.month}월 ${s.date.day}일';
    } else if (_relationshipStartDate != null) {
      // 등록된 데이트가 없으면 사귄 날부터 계산
      try {
        final start = DateTime.parse(_relationshipStartDate!);
        final now = DateTime.now();
        longingDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(start.year, start.month, start.day))
            .inDays;
        lastDateLabel =
            '${start.month}월 ${start.day}일';
      } catch (_) {}
    }

    // 다음 만남
    int? daysUntil = _nextDateDaysUntil;
    String nextDateLabel = '';
    if (nextDate != null) {
      final s = nextDate['schedule'] as Schedule;
      nextDateLabel = '${s.date.month}월 ${s.date.day}일';
    }

    // 게이지 비율
    double progress = 0;
    if (daysUntil != null) {
      final total = longingDays + daysUntil;
      progress = total > 0 ? (longingDays / total).clamp(0.0, 1.0) : 0;
    }

    return LongingGaugeCard(
      longingDays: longingDays,
      progress: progress,
      lastDateLabel: lastDateLabel,
      nextDateLabel: nextDateLabel,
      daysUntil: daysUntil,
    );
  }

  // ── 오늘 + 내일 일정 통합 카드 ───────────────────────────────────────────

  Widget _buildScheduleCombinedCard(
    DateTime today,
    DateTime tomorrow,
    String todayWeekday,
    String tomorrowWeekday,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_note_outlined,
                    color: AppTheme.primary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '우리 일정',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // 오늘 / 내일 패널
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildSchedulePanel(
                      date: today,
                      label: '오늘',
                      weekday: todayWeekday,
                      schedules: _todaySchedules,
                      emptyText: '여유로운 하루예요',
                    ),
                  ),
                  Container(
                    width: 1,
                    color: AppTheme.border,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  Expanded(
                    child: _buildSchedulePanel(
                      date: tomorrow,
                      label: '내일',
                      weekday: tomorrowWeekday,
                      schedules: _tomorrowSchedules,
                      emptyText: '여유로운 내일이에요',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePanel({
    required DateTime date,
    required String label,
    required String weekday,
    required Map<String, List<Schedule>>? schedules,
    required String emptyText,
  }) {
    final mySchedules = schedules?['mine'] ?? [];
    final partnerSchedules = schedules?['partner'] ?? [];
    final partnerName = _partnerNickname ?? '애인';
    final hasAny = mySchedules.isNotEmpty || partnerSchedules.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CalendarScreen(initialDate: date)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  weekday,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasAny)
              Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textTertiary,
                ),
              )
            else ...[
              if (mySchedules.isNotEmpty)
                _buildMiniScheduleRow('나', mySchedules),
              if (partnerSchedules.isNotEmpty) ...[
                if (mySchedules.isNotEmpty) const SizedBox(height: 4),
                _buildMiniScheduleRow(partnerName, partnerSchedules),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _shortStationName(String station) {
    return station.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
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
              ? '${s.startTime!.hour.toString().padLeft(2, '0')}:${s.startTime!.minute.toString().padLeft(2, '0')} '
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
                    '$timeStr${s.title ?? s.category ?? '일정'}',
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
    DateTime? nextDateTime;
    if (nextDate != null) {
      try {
        final schedule = nextDate['schedule'] as Schedule;
        nextDateTime = schedule.date;
        dateLabel = '${nextDateTime.month}월 ${nextDateTime.day}일';
      } catch (_) {}
    }

    final daysText = daysUntil == null
        ? '일정 없음'
        : daysUntil == 0
        ? '오늘!'
        : daysUntil == 1
        ? '내일!'
        : 'D-$daysUntil';

    return GestureDetector(
      onTap: nextDateTime != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CalendarScreen(initialDate: nextDateTime),
                ),
              )
          : null,
      child: Container(
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
    ));
  }
}

// ─── Home Skeleton Loader ─────────────────────────────────────────────────────

class _HomeSkeletonLoader extends StatefulWidget {
  const _HomeSkeletonLoader();

  @override
  State<_HomeSkeletonLoader> createState() => _HomeSkeletonLoaderState();
}

class _HomeSkeletonLoaderState extends State<_HomeSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double radius = 10,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        final shimmerColor = Color.lerp(
          const Color(0xFFE8E0D6),
          const Color(0xFFF5F0EB),
          _shimmerAnim.value,
        )!;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth - 40;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 스켈레톤
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(width: 130, height: 13),
                    const SizedBox(height: 8),
                    _shimmerBox(width: 200, height: 22),
                  ],
                ),
              ),
              _shimmerBox(width: 36, height: 36, radius: 18),
            ],
          ),
          const SizedBox(height: 20),

          // D-Day 카드 스켈레톤
          Container(
            width: cardWidth,
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(width: 80, height: 13),
                const SizedBox(height: 12),
                _shimmerBox(width: 60, height: 40, radius: 8),
                const Spacer(),
                _shimmerBox(width: 140, height: 11),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 오늘 일정 카드 스켈레톤
          Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(width: 90, height: 14),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _shimmerBox(width: 32, height: 32, radius: 8),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(width: 60, height: 11),
                        const SizedBox(height: 6),
                        _shimmerBox(width: 120, height: 14),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _shimmerBox(width: 32, height: 32, radius: 8),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(width: 60, height: 11),
                        const SizedBox(height: 6),
                        _shimmerBox(width: 100, height: 14),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 날씨 카드 스켈레톤
          Container(
            width: cardWidth,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                _shimmerBox(width: 44, height: 44, radius: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shimmerBox(width: 80, height: 11),
                    const SizedBox(height: 6),
                    _shimmerBox(width: 50, height: 18),
                  ],
                ),
                const Spacer(),
                _shimmerBox(width: 44, height: 44, radius: 22),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shimmerBox(width: 80, height: 11),
                    const SizedBox(height: 6),
                    _shimmerBox(width: 50, height: 18),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 다음 데이트 카드 스켈레톤
          Container(
            width: cardWidth,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                _shimmerBox(width: 36, height: 36, radius: 10),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shimmerBox(width: 70, height: 11),
                    const SizedBox(height: 6),
                    _shimmerBox(width: 130, height: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


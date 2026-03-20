import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../../../core/holiday_service.dart';
import '../../../core/profile_change_notifier.dart';
import '../../../shared/models/schedule.dart';
import '../../profile/models/couple_profile.dart';
import '../../profile/services/profile_service.dart';
import '../services/home_service.dart';
import '../../calendar/widgets/schedule_detail.dart';
import '../../transport/screens/transport_search_screen.dart';
import '../../midpoint/screens/midpoint_search_screen.dart';
import 'relationship_timeline_screen.dart';

// ─── Ordinal suffix helper ────────────────────────────────────────────────────

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

// ─── Rotating Header ─────────────────────────────────────────────────────────

class _RotatingHeader extends StatefulWidget {
  final int dDays;
  final String? nickname;
  final String? relationshipStartDate;

  const _RotatingHeader({
    required this.dDays,
    this.nickname,
    this.relationshipStartDate,
  });

  @override
  State<_RotatingHeader> createState() => _RotatingHeaderState();
}

class _RotatingHeaderState extends State<_RotatingHeader>
    with SingleTickerProviderStateMixin {
  static const _prefKey = 'home_phrase_index';

  // 숫자 아래 2줄 문구 (\n으로 균형 분리)
  static const _phrases = [
    'Days of\nLove',
    'Days spent\nwith You',
    'Days of\nUs',
    'Still going\nStrong',
    'Days and\nCounting',
    'Our Story\nUnfolds',
    'Days &\nStill Yours',
  ];

  int _index = 0;
  late AnimationController _animController;
  late Animation<int> _countAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _countAnim = IntTween(begin: 0, end: widget.dDays).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _loadAndAdvance();
    _animController.forward();
  }

  @override
  void didUpdateWidget(_RotatingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dDays != widget.dDays) {
      _countAnim = IntTween(begin: 0, end: widget.dDays).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAndAdvance() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_prefKey) ?? 0;
    final next = (current + 1) % _phrases.length;
    await prefs.setInt(_prefKey, next);
    if (mounted) setState(() => _index = current);
  }

  @override
  Widget build(BuildContext context) {
    final phrase = _phrases[_index];
    final nickname = widget.nickname ?? '우리';

    return GestureDetector(
      onTap: () {
        if (widget.relationshipStartDate == null) return;
        try {
          final startedAt = DateTime.parse(widget.relationshipStartDate!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RelationshipTimelineScreen(
                startedAt: startedAt,
                myNickname: null,
                partnerNickname: widget.nickname,
              ),
            ),
          );
        } catch (_) {}
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: 인사말
          Text(
            '안녕, $nickname',
            style: GoogleFonts.notoSansKr(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          // Row 2: 숫자 카운트업 애니메이션
          AnimatedBuilder(
            animation: _countAnim,
            builder: (context, _) => Text(
              '${_countAnim.value}',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 88,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.0,
              ),
            ),
          ),
          // Row 3: 균형잡힌 2줄 문구
          Text(
            phrase,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 32,
              fontWeight: FontWeight.w300,
              color: AppTheme.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dot Indicator ───────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : AppTheme.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─── Card 1: Schedule Card ───────────────────────────────────────────────────

class _ScheduleCard extends StatefulWidget {
  final Map<String, List<Schedule>>? todaySchedules;
  final Map<String, List<Schedule>>? tomorrowSchedules;
  final String partnerName;
  final VoidCallback? onArrowTap;

  const _ScheduleCard({
    required this.todaySchedules,
    required this.tomorrowSchedules,
    required this.partnerName,
    this.onArrowTap,
  });

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  bool _isToday = true;

  @override
  Widget build(BuildContext context) {
    final schedules = _isToday ? widget.todaySchedules : widget.tomorrowSchedules;
    final mySchedules = schedules?['mine'] ?? [];
    final partnerSchedules = schedules?['partner'] ?? [];

    final bothOff = mySchedules.any((s) => s.category == '휴무') &&
        partnerSchedules.any((s) => s.category == '휴무');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardPastelSky,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [AppTheme.subtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 토글 + 화살표
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
            child: Row(
              children: [
                _ToggleTab(
                  label: "Today's Plan",
                  active: _isToday,
                  onTap: () => setState(() => _isToday = true),
                  fontSize: 13,
                ),
                const SizedBox(width: 6),
                _ToggleTab(
                  label: "Tomorrow's Plan",
                  active: !_isToday,
                  onTap: () => setState(() => _isToday = false),
                  fontSize: 13,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onArrowTap,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.textTertiary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 14,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.6),
            indent: 16,
            endIndent: 16,
          ),
          // 2컬럼 일정
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ScheduleColumn(
                      label: 'Me',
                      schedules: mySchedules,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ScheduleColumn(
                      label: widget.partnerName,
                      schedules: partnerSchedules,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 둘 다 휴무 배너
          if (bothOff)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '💕 같이 쉬는 날이에요!',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double fontSize;

  const _ToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _ScheduleColumn extends StatelessWidget {
  final String label;
  final List<Schedule> schedules;

  const _ScheduleColumn({required this.label, required this.schedules});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSansKr(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        if (schedules.isEmpty)
          Text(
            '일정 없음',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          )
        else
          ...schedules.take(3).map((s) => _ScheduleItem(schedule: s)),
        if (schedules.length > 3)
          Text(
            '+${schedules.length - 3}개',
            style: GoogleFonts.notoSansKr(
              fontSize: 10,
              color: AppTheme.textTertiary,
            ),
          ),
      ],
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final Schedule schedule;

  const _ScheduleItem({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final timeStr = schedule.startTime != null
        ? '${schedule.startTime!.hour.toString().padLeft(2, '0')}:${schedule.startTime!.minute.toString().padLeft(2, '0')} '
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$timeStr${schedule.title ?? schedule.category ?? '일정'}',
              style: GoogleFonts.notoSansKr(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card 2: Next Meeting Card ────────────────────────────────────────────────

class _NextMeetingCard extends StatelessWidget {
  final Map<String, dynamic>? nextDate;
  final DateTime? lastMeeting;
  final VoidCallback? onArrowTap;

  const _NextMeetingCard({this.nextDate, this.lastMeeting, this.onArrowTap});

  double _calcProgress(int daysUntil) {
    if (lastMeeting != null) {
      final today = DateTime.now();
      final elapsed = today.difference(lastMeeting!).inDays;
      final total = elapsed + daysUntil;
      if (total <= 0) return 1.0;
      return (elapsed / total).clamp(0.0, 1.0);
    }
    return ((14 - daysUntil) / 14).clamp(0.0, 1.0);
  }

  String _missMessage() {
    if (lastMeeting == null) return '곧 만나요, 설레는 중이에요';
    final daysSince = DateTime.now().difference(lastMeeting!).inDays;
    if (daysSince == 0) return '오늘 막 헤어졌어요';
    if (daysSince == 1) return '벌써 하루가 지났어요';
    return '보고싶은지 ${daysSince}일째에요';
  }

  @override
  Widget build(BuildContext context) {
    final daysUntil = nextDate?['days_until'] as int?;
    final schedule = nextDate?['schedule'] as Schedule?;

    if (daysUntil == null || schedule == null) {
      return _buildEmpty();
    }

    final isToday = daysUntil == 0;
    final progress = _calcProgress(daysUntil);
    final bgColor = isToday ? AppTheme.accentLight : AppTheme.cardPastelPeach;

    String dateLabel = '';
    try {
      final dt = schedule.date;
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      ];
      dateLabel = '${months[dt.month - 1]} ${dt.day}, ${weekdays[dt.weekday - 1]}';
    } catch (_) {}

    final dDayText = isToday ? '오늘!' : 'D-$daysUntil';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [AppTheme.subtleShadow],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상단: 보고싶은지 N일째  +  화살표 아이콘
          Row(
            children: [
              Expanded(
                child: Text(
                  _missMessage(),
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onArrowTap,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.textTertiary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── 중앙: 다음 만남 (대형) + 날짜
          Text(
            'Next Date',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isToday ? 'Today 💕' : dateLabel,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.1,
            ),
          ),

          const Spacer(),

          // ── 하단: 하트 아이콘 + D-day 숫자 + 게이지
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 하트/달력 아이콘 원형
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isToday
                      ? Icons.favorite_rounded
                      : Icons.calendar_month_rounded,
                  size: 16,
                  color: isToday ? AppTheme.accent : AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              // D-day 숫자
              Text(
                dDayText,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isToday ? AppTheme.accent : AppTheme.textPrimary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              // 게이지
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(
                      isToday ? AppTheme.accent : AppTheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardPastelPeach,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [AppTheme.subtleShadow],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '곧 만나요, 설레는 중이에요',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            'Next Date',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '캘린더에 등록해봐요 💌',
            style: GoogleFonts.notoSansKr(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Card 3: Transport Card ───────────────────────────────────────────────────

class _TransportCard extends StatelessWidget {
  final CoupleProfile? profile;
  final VoidCallback onTap;

  const _TransportCard({this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasInfo = profile?.hasTransportInfo == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardPastelMint,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [AppTheme.subtleShadow],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🚇', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  '가는 길도 설레어',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '지금 출발하면 언제 도착할까요',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            if (hasInfo) ...[
              Row(
                children: [
                  _StationChip(label: profile!.myStation!),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Divider(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            thickness: 1,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: AppTheme.primary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _StationChip(label: profile!.partnerStation!),
                ],
              ),
            ] else ...[
              Text(
                '역 정보를 설정하면\n교통편을 바로 확인해요',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '교통편 확인하기 →',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationChip extends StatelessWidget {
  final String label;

  const _StationChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSansKr(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

// ─── Card 4: Midpoint Card ────────────────────────────────────────────────────

class _MidpointCard extends StatelessWidget {
  final VoidCallback onTap;

  const _MidpointCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardPastelLavender,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [AppTheme.subtleShadow],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '반반 거리, 완벽한 약속장소',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '서로의 중간, 딱 공평한 만남의 중심점',
              style: GoogleFonts.notoSansKr(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            // 두 점 사이 라인 시각화
            Row(
              children: [
                _LocationDot(color: AppTheme.primary),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Divider(
                        color: AppTheme.textTertiary.withValues(alpha: 0.4),
                        thickness: 1,
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _LocationDot(color: AppTheme.accent),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '나',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
                Text(
                  '파트너',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '중간지점 찾아보기 →',
                style: GoogleFonts.notoSansKr(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationDot extends StatelessWidget {
  final Color color;

  const _LocationDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

// ─── Home Card Pager ─────────────────────────────────────────────────────────

class _HomeCardPager extends StatefulWidget {
  final Map<String, List<Schedule>>? todaySchedules;
  final Map<String, List<Schedule>>? tomorrowSchedules;
  final Map<String, dynamic>? nextDate;
  final DateTime? lastMeeting;
  final String partnerName;
  final CoupleProfile? profile;

  const _HomeCardPager({
    required this.todaySchedules,
    required this.tomorrowSchedules,
    required this.nextDate,
    required this.lastMeeting,
    required this.partnerName,
    required this.profile,
  });

  @override
  State<_HomeCardPager> createState() => _HomeCardPagerState();
}

class _HomeCardPagerState extends State<_HomeCardPager> {
  static const _cardCount = 4;
  static const _loopMultiplier = 500;
  static const _initialPage = _cardCount * _loopMultiplier;

  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: 0.72,
      initialPage: _initialPage,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCard(BuildContext context, int realIndex) {
    switch (realIndex) {
      case 0:
        return _ScheduleCard(
          todaySchedules: widget.todaySchedules,
          tomorrowSchedules: widget.tomorrowSchedules,
          partnerName: widget.partnerName,
          onArrowTap: () {
            final schedules = widget.todaySchedules;
            final first = (schedules?['mine']?.isNotEmpty == true)
                ? schedules!['mine']!.first
                : (schedules?['partner']?.isNotEmpty == true)
                    ? schedules!['partner']!.first
                    : null;
            if (first == null || first.userId == 'system') return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScheduleDetailScreen(schedule: first),
              ),
            );
          },
        );
      case 1:
        return _NextMeetingCard(
          nextDate: widget.nextDate,
          lastMeeting: widget.lastMeeting,
          onArrowTap: () {
            final schedule = widget.nextDate?['schedule'] as Schedule?;
            if (schedule == null || schedule.userId == 'system') return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScheduleDetailScreen(schedule: schedule),
              ),
            );
          },
        );
      case 2:
        return _TransportCard(
          profile: widget.profile,
          onTap: () {
            final p = widget.profile;
            if (p?.hasTransportInfo == true) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransportSearchScreen(
                    fromStation: p!.myStation!,
                    toStation: p.partnerStation!,
                  ),
                ),
              );
            }
          },
        );
      default:
        return _MidpointCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MidpointSearchScreen()),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = MediaQuery.of(context).size.height * 0.32;

    return Column(
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _controller,
            clipBehavior: Clip.none,
            itemCount: _cardCount * _loopMultiplier * 2,
            onPageChanged: (i) =>
                setState(() => _currentPage = i % _cardCount),
            itemBuilder: (context, index) {
              final realIndex = index % _cardCount;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildCard(context, realIndex),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _DotIndicator(count: _cardCount, current: _currentPage),
      ],
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
    _profileChangeSub = ProfileChangeNotifier().onChange.listen((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedOnce) _loadData();
    _hasLoadedOnce = true;
  }

  void _setupRealtime() {
    if (_coupleId == null || _schedulesChannel != null) return;

    _schedulesChannel = Supabase.instance.client
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
            if (mounted) _loadData();
          },
        )
      ..subscribe();

    _couplesChannel ??= Supabase.instance.client
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
        _checkNotifications(_data);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkNotifications(Map<String, dynamic> data) async {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final nm = NotificationManager();

    final todaySchedules =
        data['today_schedules'] as Map<String, List<Schedule>>?;
    if (todaySchedules != null) {
      final allToday = <Schedule>[
        ...(todaySchedules['mine'] ?? []),
        ...(todaySchedules['partner'] ?? []),
      ];
      await nm.checkDateToday(schedules: allToday, today: today);

      final myOff =
          (todaySchedules['mine'] ?? []).where((s) => s.category == '휴무').toList();
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

  // ── Data getters ────────────────────────────────────────────────────────
  int? get _dDays => _data['d_days']?['days'] as int?;
  String? get _partnerNickname =>
      _data['d_days']?['partner_nickname'] as String?;
  Map<String, List<Schedule>>? get _todaySchedules =>
      _data['today_schedules'] as Map<String, List<Schedule>>?;
  Map<String, List<Schedule>>? get _tomorrowSchedules =>
      _data['tomorrow_schedules'] as Map<String, List<Schedule>>?;
  Map<String, dynamic>? get _nextDate =>
      _data['next_date'] as Map<String, dynamic>?;
  DateTime? get _lastMeeting => _data['last_meeting'] as DateTime?;
  String? get _relationshipStartDate =>
      _data['d_days']?['started_at'] as String?;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupleId == null
          ? _buildNoCoupleState()
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: _buildHomeContent(),
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
          Text(
            '커플 연결이 필요합니다',
            style: GoogleFonts.notoSansKr(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    final dDays = _dDays ?? 0;
    final partnerName = _partnerNickname ?? '애인';
    final today = DateTime.now();
    final todayHolidays = HolidayService().getHolidays(today);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _RotatingHeader(
                    dDays: dDays,
                    nickname: partnerName,
                    relationshipStartDate: _relationshipStartDate,
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
          ),

          // 공휴일 배너
          if (todayHolidays.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  todayHolidays.map((h) => '${h.emoji} ${h.name}').join('  ·  '),
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // ── 스와이프 카드 ─────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: _HomeCardPager(
              todaySchedules: _todaySchedules,
              tomorrowSchedules: _tomorrowSchedules,
              nextDate: _nextDate,
              lastMeeting: _lastMeeting,
              partnerName: partnerName,
              profile: _profile,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

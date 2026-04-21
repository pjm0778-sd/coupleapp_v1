import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/holiday_service.dart';
import '../../../shared/models/schedule.dart';
import 'schedule_detail.dart';

class DayDetailSheet extends StatefulWidget {
  final DateTime date;
  final List<Schedule> schedules; // 이미 sortByOwner 적용된 리스트
  final List<Holiday> holidays;
  final String myUserId;
  final String? partnerNickname;
  final Color Function(Schedule) getColor;
  final Future<void> Function(Schedule) onEdit;
  final Future<void> Function(Schedule) onDelete;
  final VoidCallback onAddTap;

  const DayDetailSheet({
    super.key,
    required this.date,
    required this.schedules,
    required this.holidays,
    required this.myUserId,
    required this.partnerNickname,
    required this.getColor,
    required this.onEdit,
    required this.onDelete,
    required this.onAddTap,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required List<Schedule> schedules,
    required List<Holiday> holidays,
    required String myUserId,
    required String? partnerNickname,
    required Color Function(Schedule) getColor,
    required Future<void> Function(Schedule) onEdit,
    required Future<void> Function(Schedule) onDelete,
    required VoidCallback onAddTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.88,
        snap: true,
        snapSizes: const [0.5, 0.88],
        builder: (_, scrollController) => DayDetailSheet(
          date: date,
          schedules: schedules,
          holidays: holidays,
          myUserId: myUserId,
          partnerNickname: partnerNickname,
          getColor: getColor,
          onEdit: onEdit,
          onDelete: onDelete,
          onAddTap: onAddTap,
        ),
      ),
    );
  }

  @override
  State<DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<DayDetailSheet> {
  late List<Schedule> _schedules;

  @override
  void initState() {
    super.initState();
    _schedules = List.from(widget.schedules);
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[widget.date.weekday - 1];
    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;

    final nonAnniv = _schedules.where((s) => !s.isAnniversary).toList();
    final anniv = _schedules.where((s) => s.isAnniversary).toList();
    final publicHoliday = widget.holidays.where(
      (h) => h.type == HolidayType.publicHoliday,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── 드래그 핸들 ──
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── 날짜 헤더 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isToday)
                      Text(
                        '오늘',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      '${widget.date.month}월 ${widget.date.day}일 ($wd)',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (publicHoliday.isNotEmpty)
                      Text(
                        publicHoliday.first.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE53935),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // 일정 추가 버튼
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onAddTap();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '일정 추가',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // ── 일정 목록 ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // 기념일 배너
                if (anniv.isNotEmpty)
                  _AnniversaryBanner(anniversaries: anniv),

                // 일정 없을 때
                if (nonAnniv.isEmpty && anniv.isEmpty)
                  const _EmptyState(),

                if (nonAnniv.isEmpty && anniv.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      '이날 일정이 없어요',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),

                // 일정 카드들
                ...nonAnniv.map(
                  (s) => _ScheduleRow(
                    schedule: s,
                    myUserId: widget.myUserId,
                    partnerNickname: widget.partnerNickname,
                    color: widget.getColor(s),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduleDetailScreen(schedule: s),
                      ),
                    ),
                    onEdit: () async {
                      Navigator.pop(context);
                      await widget.onEdit(s);
                    },
                    onDelete: () async {
                      // 시트 닫지 않고 목록에서만 제거
                      setState(() => _schedules.remove(s));
                      await widget.onDelete(s);
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// 기념일 배너
// ────────────────────────────────────────────────────
class _AnniversaryBanner extends StatelessWidget {
  final List<Schedule> anniversaries;
  const _AnniversaryBanner({required this.anniversaries});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              anniversaries.map((a) => a.title ?? '').join(' · '),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE91E63),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// 일정 없는 상태
// ────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 12),
          Text(
            '이날 일정이 없어요',
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            '+ 일정 추가 버튼을 눌러 등록해 보세요',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// 일정 카드 한 줄
// ────────────────────────────────────────────────────
class _ScheduleRow extends StatelessWidget {
  final Schedule schedule;
  final String myUserId;
  final String? partnerNickname;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleRow({
    required this.schedule,
    required this.myUserId,
    required this.partnerNickname,
    required this.color,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = _buildTimeStr();

    return Dismissible(
      key: ValueKey(schedule.id),
      direction: DismissDirection.horizontal,
      // 오른쪽 스와이프 → 수정
      background: _swipeBg(
        alignment: Alignment.centerLeft,
        color: const Color(0xFF2196F3),
        icon: Icons.edit_outlined,
        label: '수정',
      ),
      // 왼쪽 스와이프 → 삭제
      secondaryBackground: _swipeBg(
        alignment: Alignment.centerRight,
        color: Colors.red,
        icon: Icons.delete_outline,
        label: '삭제',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false; // 아이템 유지
        } else {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('일정 삭제'),
              content: const Text('이 일정을 삭제할까요?'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('삭제'),
                ),
              ],
            ),
          );
          return confirmed ?? false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // 소유자 뱃지
            _OwnerBadge(
              ownerType: schedule.ownerType,
              userId: schedule.userId,
              myUserId: myUserId,
              color: color,
            ),
            const SizedBox(width: 10),
            // 제목 + 시간
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.title ?? schedule.workType ?? '(제목 없음)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (schedule.location != null &&
                      schedule.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          schedule.location!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // ⋯ 메뉴
            GestureDetector(
              onTap: () => _showActionSheet(context),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.more_horiz,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),  // Container
    ),  // InkWell
    ); // Dismissible
  }

  Widget _swipeBg({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _buildTimeStr() {
    if (schedule.startTime == null && schedule.endTime == null) return '종일';
    if (schedule.startTime == null) return '';
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (schedule.endTime == null) return fmt(schedule.startTime!);
    return '${fmt(schedule.startTime!)} ~ ${fmt(schedule.endTime!)}';
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('수정하기'),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              title: const Text(
                '삭제하기',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('취소'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// 소유자 뱃지 (나 / 파 / 우)
// ────────────────────────────────────────────────────
class _OwnerBadge extends StatelessWidget {
  final String ownerType;
  final String userId;
  final String myUserId;
  final Color color;

  const _OwnerBadge({
    required this.ownerType,
    required this.userId,
    required this.myUserId,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final (label, bg) = switch (ownerType) {
      'couple' => ('우', const Color(0xFFFF6B9D)),
      'partner' => ('파', const Color(0xFF9C6FE4)),
      _ => userId == myUserId
          ? ('나', const Color(0xFF4F86F7))
          : ('파', const Color(0xFF9C6FE4)),
    };

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: bg,
        ),
      ),
    );
  }
}

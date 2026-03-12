import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/holiday_service.dart';
import '../../../shared/models/schedule.dart';

class CalendarCard extends StatefulWidget {
  final DateTime date;
  final String weekday;
  final bool isToday;
  final List<Schedule> schedules;
  final List<Holiday> holidays;
  final void Function(Schedule) onScheduleTap;
  final IconData Function(String?) getCategoryIcon;
  final String Function(TimeOfDay?) formatTime;
  final String Function(TimeOfDay?, TimeOfDay?) formatTimeRange;

  const CalendarCard({
    super.key,
    required this.date,
    required this.weekday,
    required this.isToday,
    required this.schedules,
    this.holidays = const [],
    required this.onScheduleTap,
    required this.getCategoryIcon,
    required this.formatTime,
    required this.formatTimeRange,
  });

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  bool _isExpanded = false;

  Color _getScheduleColor(Schedule schedule) {
    if (schedule.colorHex != null && schedule.colorHex!.isNotEmpty) {
      try {
        return Color(int.parse('FF${schedule.colorHex!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    switch (schedule.category) {
      case '근무': return const Color(0xFF4CAF50);
      case '약속': return const Color(0xFF2196F3);
      case '여행': return const Color(0xFFFF9800);
      case '데이트': return const Color(0xFFE91E63);
      case '휴무': return const Color(0xFFBDBDBD);
      default: return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${widget.date.month}월 ${widget.date.day}일';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isToday ? AppTheme.primary : AppTheme.border,
          width: widget.isToday ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          title: Row(
            children: [
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isToday ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '오늘',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    widget.weekday,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (widget.holidays.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ...widget.holidays.take(2).map((h) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: h.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${h.emoji} ${h.name}',
                            style: TextStyle(
                              fontSize: 10,
                              color: h.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )),
                  ],
                ],
              ),
              if (!_isExpanded && widget.schedules.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: widget.schedules.take(5).map((s) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _getScheduleColor(s),
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: widget.schedules.isEmpty
                    ? [
                        _EmptyState(
                          message: widget.isToday ? '오늘 일정이 없어요' : '일정이 없어요',
                          icon: Icons.event_note_outlined,
                        )
                      ]
                    : widget.schedules.asMap().entries.map((entry) {
                        final index = entry.key;
                        final schedule = entry.value;
                        return _ScheduleItem(
                          schedule: schedule,
                          isFirst: index == 0,
                          onTap: () => widget.onScheduleTap(schedule),
                          getCategoryIcon: widget.getCategoryIcon,
                          formatTime: widget.formatTime,
                          formatTimeRange: widget.formatTimeRange,
                        );
                      }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final Schedule schedule;
  final bool isFirst;
  final VoidCallback onTap;
  final IconData Function(String?) getCategoryIcon;
  final String Function(TimeOfDay?) formatTime;
  final String Function(TimeOfDay?, TimeOfDay?) formatTimeRange;

  const _ScheduleItem({
    super.key,
    required this.schedule,
    required this.isFirst,
    required this.onTap,
    required this.getCategoryIcon,
    required this.formatTime,
    required this.formatTimeRange,
  });

  /// 일정 색상 계산 (colorHex 우선, 아니면 category 기준)
  Color _getScheduleColor(Schedule schedule) {
    if (schedule.colorHex != null && schedule.colorHex!.isNotEmpty) {
      try {
        return Color(int.parse('FF${schedule.colorHex!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    // category 기준 색상
    return _getCategoryColor(schedule.category);
  }

  /// 카테고리 기준 색상
  Color _getCategoryColor(String? category) {
    switch (category) {
      case '근무':
        return const Color(0xFF4CAF50);
      case '약속':
        return const Color(0xFF2196F3);
      case '여행':
        return const Color(0xFFFF9800);
      case '데이트':
        return const Color(0xFFE91E63);
      case '휴무':
        return const Color(0xFFBDBDBD);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = schedule.title ?? schedule.workType ?? '일정';
    final category = schedule.category;
    final scheduleColor = _getScheduleColor(schedule);
    final categoryIcon = getCategoryIcon(category);
    final timeRange = formatTimeRange(schedule.startTime, schedule.endTime);
    final hasLocation = schedule.location != null && schedule.location!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: EdgeInsets.only(top: isFirst ? 0 : 8),
        decoration: BoxDecoration(
          color: scheduleColor.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 카테고리 아이콘
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheduleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                categoryIcon,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // 일정 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (timeRange.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeRange,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (hasLocation) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            schedule.location!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // 화살표 아이콘
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyState({
    super.key,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppTheme.textSecondary.withOpacity(0.4),
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

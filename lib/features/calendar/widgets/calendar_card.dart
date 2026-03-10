import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule.dart';

class CalendarCard extends StatelessWidget {
  final DateTime date;
  final String weekday;
  final bool isToday;
  final List<Schedule> schedules;
  final void Function(Schedule) onScheduleTap;
  final Color Function(String?) getCategoryColor;
  final IconData Function(String?) getCategoryIcon;
  final String Function(TimeOfDay?) formatTime;
  final String Function(TimeOfDay?, TimeOfDay?) formatTimeRange;

  const CalendarCard({
    super.key,
    required this.date,
    required this.weekday,
    required this.isToday,
    required this.schedules,
    required this.onScheduleTap,
    required this.getCategoryColor,
    required this.getCategoryIcon,
    required this.formatTime,
    required this.formatTimeRange,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = '${date.month}월 ${date.day}일';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? AppTheme.primary : AppTheme.border,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 헤더
            Row(
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isToday ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                if (isToday)
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
            const SizedBox(height: 8),
            // 요일 표시
            Text(
              weekday,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // 일정 목록
            if (schedules.isEmpty)
              _EmptyState(
                message: isToday ? '오늘 일정이 없어요' : '일정이 없어요',
                icon: Icons.event_note_outlined,
              )
            else
              ...schedules.asMap().entries.map((entry) {
                final index = entry.key;
                final schedule = entry.value;
                return _ScheduleItem(
                  schedule: schedule,
                  isFirst: index == 0,
                  onTap: () => onScheduleTap(schedule),
                  getCategoryColor: getCategoryColor,
                  getCategoryIcon: getCategoryIcon,
                  formatTime: formatTime,
                  formatTimeRange: formatTimeRange,
                );
              }),
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
  final Color Function(String?) getCategoryColor;
  final IconData Function(String?) getCategoryIcon;
  final String Function(TimeOfDay?) formatTime;
  final String Function(TimeOfDay?, TimeOfDay?) formatTimeRange;

  const _ScheduleItem({
    super.key,
    required this.schedule,
    required this.isFirst,
    required this.onTap,
    required this.getCategoryColor,
    required this.getCategoryIcon,
    required this.formatTime,
    required this.formatTimeRange,
  });

  @override
  Widget build(BuildContext context) {
    final title = schedule.title ?? schedule.workType ?? '일정';
    final category = schedule.category;
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);
    final timeRange = formatTimeRange(schedule.startTime, schedule.endTime);
    final hasLocation = schedule.location != null && schedule.location!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: EdgeInsets.only(top: isFirst ? 0 : 8),
        decoration: BoxDecoration(
          color: categoryColor.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 카테고리 아이콘
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: categoryColor,
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

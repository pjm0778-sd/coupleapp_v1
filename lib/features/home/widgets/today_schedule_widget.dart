import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule.dart';

class TodayScheduleWidget extends StatelessWidget {
  final Map<String, List<Schedule>> todaySchedules;
  final String weekday;
  final String title;
  final String? partnerNickname;
  final void Function(Schedule)? onScheduleTap;

  const TodayScheduleWidget({
    super.key,
    required this.todaySchedules,
    required this.weekday,
    this.title = '오늘의 일정',
    this.partnerNickname,
    this.onScheduleTap,
  });

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
        return const Color(0xFF9E9E9E);
      default:
        return AppTheme.primary;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '근무':
        return Icons.work_outline;
      case '약속':
        return Icons.handshake_outlined;
      case '여행':
        return Icons.flight_takeoff_outlined;
      case '데이트':
        return Icons.favorite_outline;
      case '휴무':
        return Icons.beach_access_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null || end == null) return '';
    return '${_formatTime(start)} ~ ${_formatTime(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final mySchedules = todaySchedules['mine'] ?? [];
    final partnerSchedules = todaySchedules['partner'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              weekday,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 일정 목록
        if (mySchedules.isEmpty && partnerSchedules.isEmpty)
          _buildEmptyState()
        else ...[
          if (mySchedules.isNotEmpty) ...[
            _buildPersonChip('나'),
            const SizedBox(height: 8),
            ...mySchedules.map((s) => _ScheduleItem(
                  schedule: s,
                  getCategoryColor: _getCategoryColor,
                  getCategoryIcon: _getCategoryIcon,
                  formatTimeRange: _formatTimeRange,
                  onTap: onScheduleTap,
                )),
          ],
          if (partnerSchedules.isNotEmpty) ...[
            if (mySchedules.isNotEmpty) const SizedBox(height: 14),
            _buildPersonChip(partnerNickname ?? '상대방'),
            const SizedBox(height: 8),
            ...partnerSchedules.map((s) => _ScheduleItem(
                  schedule: s,
                  getCategoryColor: _getCategoryColor,
                  getCategoryIcon: _getCategoryIcon,
                  formatTimeRange: _formatTimeRange,
                  onTap: onScheduleTap,
                )),
          ],
        ],
      ],
    );
  }

  Widget _buildPersonChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.accent,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.border.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_note_outlined,
              size: 28,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '오늘 일정이 없어요',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '여유로운 하루를 보내세요 ☀️',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final Schedule schedule;
  final Color Function(String?) getCategoryColor;
  final IconData Function(String?) getCategoryIcon;
  final String Function(TimeOfDay?, TimeOfDay?) formatTimeRange;
  final void Function(Schedule)? onTap;

  const _ScheduleItem({
    required this.schedule,
    required this.getCategoryColor,
    required this.getCategoryIcon,
    required this.formatTimeRange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = schedule.title ?? schedule.workType ?? '일정';
    final category = schedule.category;
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);
    final timeRange = formatTimeRange(schedule.startTime, schedule.endTime);
    final hasLocation =
        schedule.location != null && schedule.location!.isNotEmpty;

    return GestureDetector(
      onTap: onTap != null ? () => onTap!(schedule) : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppTheme.subtleShadow],
        border: Border(
          left: BorderSide(color: categoryColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 카테고리 아이콘
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(categoryIcon, color: categoryColor, size: 20),
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
                      fontSize: 15,
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
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 2),
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
            // 카테고리 뱃지
            if (category != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

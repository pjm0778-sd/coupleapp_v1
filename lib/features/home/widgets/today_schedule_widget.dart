import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule.dart';

class TodayScheduleWidget extends StatelessWidget {
  final Map<String, List<Schedule>> todaySchedules;
  final String weekday;
  final String title;

  const TodayScheduleWidget({
    super.key,
    required this.todaySchedules,
    required this.weekday,
    this.title = '?ㅻ뒛???쇱젙',
  });

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '洹쇰Т':
        return const Color(0xFF4CAF50);
      case '?쎌냽':
        return const Color(0xFF2196F3);
      case '?ы뻾':
        return const Color(0xFFFF9800);
      case '?곗씠??:
        return const Color(0xFFE91E63);
      case '?대Т':
        return const Color(0xFFBDBDBD);
      default:
        return AppTheme.primary;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '洹쇰Т':
        return Icons.work_outline;
      case '?쎌냽':
        return Icons.handshake_outlined;
      case '?ы뻾':
        return Icons.flight_takeoff_outlined;
      case '?곗씠??:
        return Icons.favorite_outline;
      case '?대Т':
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

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ?ㅻ뜑
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ?쇱젙 紐⑸줉
            if (mySchedules.isEmpty && partnerSchedules.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 48,
                      color: AppTheme.textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '?ㅻ뒛 ?쇱젙???놁뼱??,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // ???쇱젙
              if (mySchedules.isNotEmpty) ...[
                _buildScheduleSection('??, mySchedules),
                const SizedBox(height: 20),
              ],
              // ?뚰듃???쇱젙
              if (partnerSchedules.isNotEmpty) ...[
                _buildScheduleSection('?뚰듃??, partnerSchedules),
              ],
            ],
          ],
        ),
      );
  }

  Widget _buildScheduleSection(String title, List<Schedule> schedules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...schedules.asMap().entries.map((entry) {
          final index = entry.key;
          final schedule = entry.value;
          return _ScheduleItem(
            schedule: schedule,
            index: index,
            getCategoryColor: _getCategoryColor,
            getCategoryIcon: _getCategoryIcon,
            formatTime: _formatTime,
            formatTimeRange: _formatTimeRange,
          );
        }),
      ],
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final Schedule schedule;
  final int index;
  final Color Function(String?) getCategoryColor;
  final IconData Function(String?) getCategoryIcon;
  final String Function(TimeOfDay?) formatTime;
  final String Function(TimeOfDay?, TimeOfDay?) formatTimeRange;

  const _ScheduleItem({
    super.key,
    required this.schedule,
    required this.index,
    required this.getCategoryColor,
    required this.getCategoryIcon,
    required this.formatTime,
    required this.formatTimeRange,
  });

  @override
  Widget build(BuildContext context) {
    final title = schedule.title ?? schedule.workType ?? '?쇱젙';
    final category = schedule.category;
    final categoryColor = getCategoryColor(category);
    final categoryIcon = getCategoryIcon(category);
    final timeRange = formatTimeRange(schedule.startTime, schedule.endTime);
    final hasLocation = schedule.location != null && schedule.location!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(15 / 255),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 移댄뀒怨좊━ ?꾩씠肄?
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
          // ?쇱젙 ?뺣낫
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
                              color: AppTheme.textPrimary,
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
        ],
      ),
    );
  }
}

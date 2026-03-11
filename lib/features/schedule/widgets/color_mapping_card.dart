import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/color_mapping.dart';

class ColorMappingCard extends StatelessWidget {
  final ColorMapping mapping;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const ColorMappingCard({
    super.key,
    required this.mapping,
    required this.onDelete,
    this.onEdit,
  });

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = mapping.startTime != null && mapping.endTime != null
        ? '${_formatTime(mapping.startTime)} ~ ${_formatTime(mapping.endTime)}'
        : '시간 미설정';

    final isNightShift = mapping.startTime != null && mapping.endTime != null &&
        mapping.startTime!.hour > mapping.endTime!.hour;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Row(
        children: [
          // 색상
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _hexToColor(mapping.colorHex),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mapping.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (isNightShift) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.bedtime_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 수정 버튼
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              style: IconButton.styleFrom(foregroundColor: AppTheme.textSecondary),
              tooltip: '수정',
            ),
          // 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            style: IconButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }
}

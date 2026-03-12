import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../features/calendar/services/schedule_service.dart';

class CalendarFilterWidget extends StatelessWidget {
  final ScheduleFilter currentFilter;
  final Function(ScheduleFilter) onFilterChanged;

  const CalendarFilterWidget({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '?꾪꽣',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: '?섎쭔',
                isSelected: currentFilter == ScheduleFilter.mine,
                onTap: () => onFilterChanged(ScheduleFilter.mine),
              ),
              _FilterChip(
                label: '?뚰듃?덈쭔',
                isSelected: currentFilter == ScheduleFilter.partner,
                onTap: () => onFilterChanged(ScheduleFilter.partner),
              ),
              _FilterChip(
                label: '????,
                isSelected: currentFilter == ScheduleFilter.both,
                onTap: () => onFilterChanged(ScheduleFilter.both),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

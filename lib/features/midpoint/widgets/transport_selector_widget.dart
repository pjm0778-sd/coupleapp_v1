import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/midpoint_input.dart';

class TransportSelectorWidget extends StatelessWidget {
  final String label;
  final TransportMode selectedMode;
  final CarType? selectedCarType;
  final ValueChanged<TransportMode> onModeChanged;
  final ValueChanged<CarType> onCarTypeChanged;

  const TransportSelectorWidget({
    super.key,
    required this.label,
    required this.selectedMode,
    this.selectedCarType,
    required this.onModeChanged,
    required this.onCarTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        // 대중교통 / 자차 선택
        Row(
          children: [
            _ModeButton(
              icon: '🚇',
              label: '대중교통',
              selected: selectedMode == TransportMode.publicTransit,
              onTap: () => onModeChanged(TransportMode.publicTransit),
            ),
            const SizedBox(width: 8),
            _ModeButton(
              icon: '🚗',
              label: '자차',
              selected: selectedMode == TransportMode.car,
              onTap: () => onModeChanged(TransportMode.car),
            ),
          ],
        ),
        // 자차 선택 시 일반/전기 구분
        if (selectedMode == TransportMode.car) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _CarTypeButton(
                icon: '⛽',
                label: '일반차',
                selected: selectedCarType == CarType.normal,
                onTap: () => onCarTypeChanged(CarType.normal),
              ),
              const SizedBox(width: 8),
              _CarTypeButton(
                icon: '⚡',
                label: '전기차',
                selected: selectedCarType == CarType.electric,
                onTap: () => onCarTypeChanged(CarType.electric),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppTheme.accent : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarTypeButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CarTypeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary.withOpacity(0.06) : AppTheme.background,
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/midpoint_result.dart';

class MidpointCityCard extends StatelessWidget {
  final MidpointResult result;
  final bool selected;
  final VoidCallback onTap;

  const MidpointCityCard({
    super.key,
    required this.result,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final myMin = result.myRoute.durationMinutes;
    final partnerMin = result.partnerRoute.durationMinutes;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent.withOpacity(0.12) : AppTheme.surface,
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.city.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.accent : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _TimeRow(label: '나', minutes: myMin),
            const SizedBox(height: 4),
            _TimeRow(label: '상대', minutes: partnerMin),
            const SizedBox(height: 8),
            _BalanceIndicator(a: myMin, b: partnerMin),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final int minutes;

  const _TimeRow({required this.label, required this.minutes});

  String get _formatted {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m분';
    if (m == 0) return '$h시간';
    return '$h시간 $m분';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label ',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
        Text(_formatted,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _BalanceIndicator extends StatelessWidget {
  final int a;
  final int b;

  const _BalanceIndicator({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    final diff = (a - b).abs();
    final isBalanced = diff <= 20;
    return Row(
      children: [
        Icon(
          isBalanced ? Icons.balance : Icons.warning_amber_outlined,
          size: 12,
          color: isBalanced ? Colors.green[600] : Colors.orange[600],
        ),
        const SizedBox(width: 3),
        Text(
          isBalanced ? '균형' : '차이 $diff분',
          style: TextStyle(
            fontSize: 10,
            color: isBalanced ? Colors.green[600] : Colors.orange[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

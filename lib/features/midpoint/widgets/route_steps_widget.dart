import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/midpoint_result.dart';

/// 경로 세부 단계 표시 (지하철 환승, KTX, 버스 등)
class RouteStepsWidget extends StatelessWidget {
  final List<RouteStep> steps;

  const RouteStepsWidget({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _StepRow(step: steps[i]),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Container(
                      width: 1,
                      height: 10,
                      color: AppTheme.border,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final RouteStep step;

  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(step.icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 수단 + 노선명
              Text(
                step.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              // 출발역 → 도착역
              if (step.startStation != null && step.endStation != null)
                Text(
                  '${step.startStation} → ${step.endStation}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        // 소요시간
        if (step.durationMinutes > 0)
          Text(
            step.durationLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
      ],
    );
  }
}

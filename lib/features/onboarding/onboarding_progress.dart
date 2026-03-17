import 'package:flutter/material.dart';
import '../../core/theme.dart';

class OnboardingProgress extends StatelessWidget {
  final int currentStep; // 0~3

  const OnboardingProgress({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final active = i == currentStep;
        final done = i < currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: done || active ? AppTheme.primary : AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

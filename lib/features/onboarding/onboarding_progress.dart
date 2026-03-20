import 'package:flutter/material.dart';
import '../../core/theme.dart';

class OnboardingProgress extends StatelessWidget {
  final int currentStep; // 0~3

  const OnboardingProgress({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i == currentStep;
        final done = i < currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
          height: 8,
          width: active ? 20 : 8,
          decoration: BoxDecoration(
            color: done || active ? AppTheme.accent : AppTheme.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

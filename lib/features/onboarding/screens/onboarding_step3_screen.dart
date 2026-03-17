import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../profile/models/couple_profile.dart';
import '../onboarding_progress.dart';
import '../widgets/city_selector_widget.dart';

class OnboardingStep3Screen extends StatelessWidget {
  final int currentStep;
  final CoupleProfile draft;
  final ValueChanged<CoupleProfile> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingStep3Screen({
    super.key,
    required this.currentStep,
    required this.draft,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  static const _options = [
    ('same_city', '🏙️', '같은 도시', '30분 이내'),
    ('near', '🚌', '근거리', '1~2시간'),
    ('long_distance', '🚆', '장거리', '다른 도시'),
  ];

  @override
  Widget build(BuildContext context) {
    final isLong = draft.distanceType == 'long_distance';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingProgress(currentStep: currentStep),
          const SizedBox(height: 40),
          const Text(
            '서로 얼마나 멀리 있나요?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 32),
          ..._options.map((opt) {
            final selected = draft.distanceType == opt.$1;
            return GestureDetector(
              onTap: () => onChanged(draft.copyWith(distanceType: opt.$1)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(opt.$2, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(opt.$3,
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: selected ? AppTheme.primary : AppTheme.textPrimary,
                            )),
                        Text(opt.$4,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primary, size: 20),
                  ],
                ),
              ),
            );
          }),

          // 장거리 선택 시 도시/역 설정
          if (isLong) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  CitySelectorWidget(
                    label: '내 거주 도시 / 역',
                    selectedCity: draft.myCity,
                    selectedStation: draft.myStation,
                    onCityChanged: (v) => onChanged(draft.copyWith(myCity: v, myStation: null)),
                    onStationChanged: (v) => onChanged(draft.copyWith(myStation: v)),
                  ),
                  const SizedBox(height: 16),
                  CitySelectorWidget(
                    label: '파트너 거주 도시 / 역',
                    selectedCity: draft.partnerCity,
                    selectedStation: draft.partnerStation,
                    onCityChanged: (v) => onChanged(draft.copyWith(partnerCity: v, partnerStation: null)),
                    onStationChanged: (v) => onChanged(draft.copyWith(partnerStation: v)),
                  ),
                  const SizedBox(height: 10),
                  const Row(children: [
                    Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 6),
                    Text('교통편 추천에 자동으로 활용됩니다',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ]),
                ],
              ),
            ),
          ],

          const Spacer(),
          Row(children: [
            OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('이전'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('다음', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

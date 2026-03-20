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
          const SizedBox(height: 20),
          const _DistanceIllustration(),
          const SizedBox(height: 24),
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
                  color: selected ? AppTheme.accentLight : AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppTheme.accent : AppTheme.border,
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selected ? AppTheme.accent : AppTheme.textPrimary,
                            )),
                        Text(opt.$4,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent, size: 20),
                  ],
                ),
              ),
            );
          }),

          // 장거리 선택 시 내 도시/역 설정
          if (isLong) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [AppTheme.subtleShadow],
              ),
              child: Column(
                children: [
                  CitySelectorWidget(
                    label: '내 거주 도시 / 역',
                    selectedCity: draft.myCity,
                    selectedStation: draft.myStation,
                    onCityChanged: (v) =>
                        onChanged(draft.copyWith(myCity: v, myStation: null)),
                    onStationChanged: (v) =>
                        onChanged(draft.copyWith(myStation: v)),
                  ),
                  const SizedBox(height: 10),
                  const Row(children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('파트너 거주지는 설정에서 입력할 수 있어요',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('이전'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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

// ---------------------------------------------------------------------------
// Distance Illustration — two nurses with a dashed line + heart between them
// ---------------------------------------------------------------------------

class _DistanceIllustration extends StatelessWidget {
  const _DistanceIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F3F1),
              Color(0xFFD0E8E4),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circle top-right
            Positioned(
              top: -24,
              right: -24,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D7068).withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Main row: nurse left — dashed line + heart — nurse right
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left nurse (looking right, normal orientation)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNurseFigure(scale: 0.85),
                      const SizedBox(height: 4),
                      const Text(
                        '나',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3D7068),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Dashed line with heart
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _DashedLineWithHeart(),
                    ),
                  ),

                  // Right nurse (mirrored, looking left)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNurseFigure(scale: 0.85, mirrorX: true),
                      const SizedBox(height: 4),
                      const Text(
                        '파트너',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3D7068),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNurseFigure({double scale = 1.0, bool mirrorX = false}) {
    return Transform.scale(
      scale: scale,
      child: Transform.flip(
        flipX: mirrorX,
        child: SizedBox(
          width: 60,
          height: 90,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Head
              Positioned(
                top: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB6A3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE8927A),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Nurse cap
              Positioned(
                top: 2,
                child: Container(
                  width: 36,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 8,
                    height: 6,
                    color: const Color(0xFF3D7068),
                  ),
                ),
              ),
              // Body (uniform)
              Positioned(
                top: 34,
                child: Container(
                  width: 44,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    border: Border.all(
                      color: const Color(0xFF3D7068),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.topCenter,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: _CrossSymbol(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLineWithHeart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedLinePainter(),
      child: const Center(
        child: Text(
          '❤️',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3D7068).withOpacity(0.45)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final centerY = size.height / 2;
    // Leave a gap in the middle for the heart emoji
    final midLeft = size.width / 2 - 18.0;
    final midRight = size.width / 2 + 18.0;

    // Left segment
    double x = 0;
    while (x < midLeft) {
      canvas.drawLine(
        Offset(x, centerY),
        Offset((x + dashWidth).clamp(0, midLeft), centerY),
        paint,
      );
      x += dashWidth + dashSpace;
    }
    // Right segment
    x = midRight;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, centerY),
        Offset((x + dashWidth).clamp(0, size.width), centerY),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Shared nurse building blocks
// ---------------------------------------------------------------------------

class _CrossSymbol extends StatelessWidget {
  const _CrossSymbol();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 14, height: 4, color: const Color(0xFFE05C5C)),
          Container(width: 4, height: 14, color: const Color(0xFFE05C5C)),
        ],
      ),
    );
  }
}

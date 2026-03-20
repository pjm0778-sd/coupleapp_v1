import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../profile/models/couple_profile.dart';
import '../../profile/data/shift_defaults.dart' show getShiftDefaults;
import '../onboarding_progress.dart';
import '../widgets/shift_time_editor.dart';

class OnboardingStep4Screen extends StatefulWidget {
  final int currentStep;
  final CoupleProfile draft;
  final ValueChanged<CoupleProfile> onChanged;
  final VoidCallback onBack;
  final Future<void> Function() onComplete;

  const OnboardingStep4Screen({
    super.key,
    required this.currentStep,
    required this.draft,
    required this.onChanged,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<OnboardingStep4Screen> createState() => _OnboardingStep4ScreenState();
}

class _OnboardingStep4ScreenState extends State<OnboardingStep4Screen> {
  bool _isSaving = false;

  static const _patterns = [
    ('shift_3', '👩‍⚕️', '간호사 / 의료직 3교대'),
    ('shift_2', '🔄', '교대 근무 2교대'),
    ('office', '💼', '일반 직장인 (주5일)'),
    ('other', '🎨', '기타 / 프리랜서'),
  ];

  void _onPatternSelect(String pattern) {
    widget.onChanged(widget.draft.copyWith(
      workPattern: pattern,
      shiftTimes: getShiftDefaults(pattern),
    ));
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);
    await widget.onComplete();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    const showShiftEditor = true;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingProgress(currentStep: widget.currentStep),
          const SizedBox(height: 20),
          const _WorkPatternIllustration(),
          const SizedBox(height: 24),
          const Text(
            '어떤 형태로 일하세요?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 32),

          // 근무 패턴 선택
          ..._patterns.map((opt) {
            final selected = draft.workPattern == opt.$1;
            return GestureDetector(
              onTap: () => _onPatternSelect(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    Text(opt.$2, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 14),
                    Text(opt.$3,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? AppTheme.accent : AppTheme.textPrimary,
                        )),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent, size: 20),
                  ],
                ),
              ),
            );
          }),

          // 교대 근무 시간 편집기
          if (showShiftEditor) ...[
            const SizedBox(height: 20),
            const Text('근무 시간 설정',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('시간을 탭해서 수정할 수 있어요',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ShiftTimeEditor(
              shiftTimes: draft.shiftTimes,
              onChanged: (updated) =>
                  widget.onChanged(draft.copyWith(shiftTimes: updated)),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('출근 알림',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              DropdownButton<int>(
                value: draft.notifyMinutesBefore,
                underline: const SizedBox(),
                items: [10, 20, 30, 60]
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text('$m분 전')))
                    .toList(),
                onChanged: (v) =>
                    widget.onChanged(draft.copyWith(notifyMinutesBefore: v)),
              ),
            ]),
          ],

          // 자차 여부
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [AppTheme.subtleShadow],
            ),
            child: Row(
              children: [
                const Text('🚗', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('자차 있음',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('교통편 추천에 반영돼요',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Switch(
                  value: draft.hasCar,
                  onChanged: (v) =>
                      widget.onChanged(draft.copyWith(hasCar: v)),
                  activeThumbColor: AppTheme.accent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Row(children: [
            OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('이전'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('시작하기 🎉',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Work Pattern Illustration — nurse with schedule board + clock
// ---------------------------------------------------------------------------

class _WorkPatternIllustration extends StatelessWidget {
  const _WorkPatternIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 155,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE4EFed),
              Color(0xFFCCE4DF),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circle bottom-left
            Positioned(
              bottom: -28,
              left: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D7068).withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Decorative circle top-right
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFC97454).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Nurse figure
                  _buildNurseFigure(scale: 0.88),
                  const SizedBox(width: 16),

                  // Schedule board
                  _buildScheduleBoard(),
                  const SizedBox(width: 20),

                  // Clock with shift labels
                  _buildClockWithShifts(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNurseFigure({double scale = 1.0}) {
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 60,
        height: 95,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Pointing arm (right arm extended forward)
            Positioned(
              top: 42,
              right: -2,
              child: Transform.rotate(
                angle: -0.3,
                origin: const Offset(6, 0),
                child: Container(
                  width: 12,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF3D7068),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
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
    );
  }

  Widget _buildScheduleBoard() {
    return Container(
      width: 68,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3D7068),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Board header
          Container(
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFF3D7068),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              '근무표',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Rows for D / E / N shifts
          const SizedBox(height: 4),
          _shiftRow('D', const Color(0xFFFFF3CD)),
          _shiftRow('E', const Color(0xFFD4EDDA)),
          _shiftRow('N', const Color(0xFFCCE5FF)),
        ],
      ),
    );
  }

  Widget _shiftRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: color.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockWithShifts() {
    return SizedBox(
      width: 84,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Clock face
          CustomPaint(
            size: const Size(64, 64),
            painter: _ClockPainter(),
          ),
          // Shift label: D (top)
          Positioned(
            top: 0,
            child: _shiftBadge('D', const Color(0xFFFFF3CD),
                const Color(0xFFB8860B)),
          ),
          // Shift label: E (bottom-right)
          Positioned(
            bottom: 6,
            right: 0,
            child: _shiftBadge('E', const Color(0xFFD4EDDA),
                const Color(0xFF2D7A3A)),
          ),
          // Shift label: N (bottom-left)
          Positioned(
            bottom: 6,
            left: 0,
            child: _shiftBadge('N', const Color(0xFFCCE5FF),
                const Color(0xFF1A5276)),
          ),
        ],
      ),
    );
  }

  Widget _shiftBadge(String label, Color bg, Color fg) {
    return Container(
      width: 22,
      height: 18,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fg.withOpacity(0.4), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Clock face
    final facePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, facePaint);

    // Clock border
    final borderPaint = Paint()
      ..color = const Color(0xFF3D7068)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Hour markers
    final markerPaint = Paint()
      ..color = const Color(0xFF3D7068).withOpacity(0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final outerPt = Offset(
        center.dx + (radius - 4) * math.sin(angle),
        center.dy - (radius - 4) * math.cos(angle),
      );
      final innerPt = Offset(
        center.dx + (radius - 9) * math.sin(angle),
        center.dy - (radius - 9) * math.cos(angle),
      );
      canvas.drawLine(innerPt, outerPt, markerPaint);
    }

    // Hour hand (pointing ~10 o'clock)
    final hourPaint = Paint()
      ..color = const Color(0xFF3D7068)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final hourAngle = (-60) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.5) * math.sin(hourAngle),
        center.dy - (radius * 0.5) * math.cos(hourAngle),
      ),
      hourPaint,
    );

    // Minute hand (pointing ~2 o'clock)
    final minutePaint = Paint()
      ..color = const Color(0xFFC97454)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final minuteAngle = (60) * math.pi / 180;
    canvas.drawLine(
      center,
      Offset(
        center.dx + (radius * 0.72) * math.sin(minuteAngle),
        center.dy - (radius * 0.72) * math.cos(minuteAngle),
      ),
      minutePaint,
    );

    // Center dot
    canvas.drawCircle(
      center,
      3,
      Paint()..color = const Color(0xFF3D7068),
    );
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

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
          const SizedBox(height: 40),
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
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: selected ? AppTheme.accent : AppTheme.textPrimary,
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              DropdownButton<int>(
                value: draft.notifyMinutesBefore,
                underline: const SizedBox(),
                items: [10, 20, 30, 60].map((m) =>
                    DropdownMenuItem(value: m, child: Text('$m분 전'))).toList(),
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
                              fontSize: 12, color: AppTheme.textSecondary)),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('이전'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent, foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('시작하기 🎉', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

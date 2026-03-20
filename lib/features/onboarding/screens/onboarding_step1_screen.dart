import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../onboarding_progress.dart';

class OnboardingStep1Screen extends StatefulWidget {
  final int currentStep;
  final String nickname;
  final ValueChanged<String> onNicknameChanged;
  final VoidCallback onNext;

  const OnboardingStep1Screen({
    super.key,
    required this.currentStep,
    required this.nickname,
    required this.onNicknameChanged,
    required this.onNext,
  });

  @override
  State<OnboardingStep1Screen> createState() => _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState extends State<OnboardingStep1Screen> {
  late TextEditingController _nickCtrl;

  @override
  void initState() {
    super.initState();
    _nickCtrl = TextEditingController(text: widget.nickname);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  bool get _canProceed => _nickCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingProgress(currentStep: widget.currentStep),
          const SizedBox(height: 40),
          const Text(
            '안녕하세요!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '먼저 간단히 소개해 주세요 :)',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 40),
          const Text(
            '내 닉네임',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nickCtrl,
            onChanged: (v) {
              widget.onNicknameChanged(v);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: '닉네임을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '만난 날짜는 파트너 연결 후 설정에서 입력할 수 있어요',
                    style: TextStyle(fontSize: 13, color: AppTheme.accent),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceed ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('다음', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

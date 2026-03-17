import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../onboarding_progress.dart';

class OnboardingStep1Screen extends StatefulWidget {
  final int currentStep;
  final String nickname;
  final DateTime coupleStartDate;
  final ValueChanged<String> onNicknameChanged;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onNext;

  const OnboardingStep1Screen({
    super.key,
    required this.currentStep,
    required this.nickname,
    required this.coupleStartDate,
    required this.onNicknameChanged,
    required this.onDateChanged,
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.coupleStartDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) widget.onDateChanged(picked);
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
          const SizedBox(height: 24),
          const Text(
            '우리가 사귄 날짜',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('yyyy년 M월 d일').format(widget.coupleStartDate),
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceed ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
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

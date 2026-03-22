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
          const SizedBox(height: 20),
          const _NurseWavingIllustration(),
          const SizedBox(height: 24),
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

// ---------------------------------------------------------------------------
// Nurse Waving Illustration
// ---------------------------------------------------------------------------

class _NurseWavingIllustration extends StatelessWidget {
  const _NurseWavingIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F3F1), // very light sage
              Color(0xFFD0E8E4), // soft sage
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative background circles
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D7068).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: 10,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D7068).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Nurse figure with waving arm
            Positioned(
              left: 60,
              bottom: 12,
              child: _buildNurseWithWave(),
            ),

            // Speech bubble
            Positioned(
              right: 32,
              top: 24,
              child: _buildSpeechBubble(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNurseWithWave() {
    return SizedBox(
      width: 80,
      height: 130,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Raised/waving arm (left arm raised up-right)
          Positioned(
            top: 36,
            left: 0,
            child: Transform.rotate(
              angle: -0.8, // tilted upward
              origin: const Offset(6, 12),
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
          // Right arm down
          Positioned(
            top: 40,
            right: 4,
            child: Container(
              width: 12,
              height: 26,
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
          // Head
          Positioned(
            top: 0,
            left: 24,
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
              child: const Center(
                child: Text(
                  '^^',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFF8B4513),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          // Nurse cap
          Positioned(
            top: 2,
            left: 22,
            child: Container(
              width: 36,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
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
            left: 18,
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
    );
  }

  Widget _buildSpeechBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF3D7068).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '반가워요! 👋',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D7068),
            ),
          ),
        ],
      ),
    );
  }
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

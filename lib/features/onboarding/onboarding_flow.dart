import 'package:flutter/material.dart';
import '../../features/profile/models/couple_profile.dart';
import '../../features/profile/data/shift_defaults.dart' show getShiftDefaults;
import '../../features/profile/services/profile_service.dart';
import '../../core/services/feature_flag_service.dart';
import 'screens/onboarding_step1_screen.dart';
import 'screens/onboarding_step2_screen.dart';
import 'screens/onboarding_step3_screen.dart';
import 'screens/onboarding_step4_screen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // 온보딩에서 수집하는 데이터 (draft)
  String _nickname = '';

  late CoupleProfile _draft;

  @override
  void initState() {
    super.initState();
    _draft = CoupleProfile(
      distanceType: 'same_city',
      workPattern: 'shift_3',
      shiftTimes: getShiftDefaults('shift_3'),
    );
  }

  void _goNext() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _goPrev() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _complete() async {
    try {
      final service = ProfileService();
      // 닉네임 저장
      await service.saveNickname(_nickname);
      // 프로필 저장 (onboarding_completed = true)
      await service.saveProfile(
        _draft.copyWith(onboardingCompleted: true),
      );
      // FeatureFlag 갱신
      FeatureFlagService().refresh(_draft.copyWith(onboardingCompleted: true));
    } catch (e) {
      debugPrint('Onboarding save error: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            OnboardingStep1Screen(
              currentStep: _currentStep,
              nickname: _nickname,
              onNicknameChanged: (v) => setState(() => _nickname = v),
              onNext: _goNext,
            ),
            OnboardingStep2Screen(
              currentStep: _currentStep,
              onNext: _goNext,
              onBack: _goPrev,
              onSkip: _goNext,
            ),
            OnboardingStep3Screen(
              currentStep: _currentStep,
              draft: _draft,
              onChanged: (updated) => setState(() => _draft = updated),
              onNext: _goNext,
              onBack: _goPrev,
            ),
            OnboardingStep4Screen(
              currentStep: _currentStep,
              draft: _draft,
              onChanged: (updated) => setState(() => _draft = updated),
              onBack: _goPrev,
              onComplete: _complete,
            ),
          ],
        ),
      ),
    );
  }
}

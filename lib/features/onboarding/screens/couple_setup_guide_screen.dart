import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/profile_change_notifier.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../profile/models/couple_profile.dart';
import '../../profile/services/profile_service.dart';
import '../../profile/data/shift_defaults.dart' show getShiftDefaults;
import '../../profile/data/city_station_data.dart'
    show getProvinceOfCity, getBestStation;
import '../widgets/region_selector_widget.dart';
import '../widgets/shift_time_editor.dart';

class CoupleSetupGuideScreen extends StatefulWidget {
  const CoupleSetupGuideScreen({super.key});

  @override
  State<CoupleSetupGuideScreen> createState() => _CoupleSetupGuideScreenState();
}

class _CoupleSetupGuideScreenState extends State<CoupleSetupGuideScreen> {
  final _profileService = ProfileService();
  final _pageController = PageController();
  int _step = 0;
  static const _totalSteps = 3;

  CoupleProfile _draft = const CoupleProfile(
    distanceType: 'same_city',
    workPattern: 'shift_3',
    shiftTimes: [],
  );
  bool _loading = true;
  bool _saving = false;

  static const _patterns = [
    ('shift_3', '👩‍⚕️', '간호사 / 의료직 3교대'),
    ('shift_2', '🔄', '교대 근무 2교대'),
    ('office', '💼', '일반 직장인 (주5일)'),
    ('other', '🎨', '기타 / 프리랜서'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileService.loadMyProfile();
    if (mounted) {
      setState(() {
        if (profile != null) _draft = profile;
        _loading = false;
      });
    }
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _step--);
    }
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      await _profileService.saveProfile(_draft);
      FeatureFlagService().refresh(_draft);
      ProfileChangeNotifier().notify();
    } catch (e) {
      debugPrint('Setup guide save error: $e');
    }
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  const Text(
                    '커플듀티 설정',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_step + 1} / $_totalSteps',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _totalSteps,
                  minHeight: 4,
                  backgroundColor: AppTheme.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: 연애 스타일 ─────────────────────────────────
  Widget _buildStep1() {
    final isTogether = _draft.coupleType == 'together';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            '커플 연결 완료!\n어떤 연애를 하고 계세요?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '앱의 기능이 연애 스타일에 맞게 최적화돼요',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildTypeOption(
            value: 'together',
            emoji: '🏠',
            title: '매일 함께',
            subtitle: '같이 살거나 매일 만나는 사이',
            selected: isTogether,
          ),
          const SizedBox(height: 12),
          _buildTypeOption(
            value: 'distance',
            emoji: '💌',
            title: '설레는 거리',
            subtitle: '따로 살거나 장거리 연애 중',
            selected: !isTogether,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                '다음',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _complete,
              child: const Text(
                '나중에 설정하기',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String value,
    required String emoji,
    required String title,
    required String subtitle,
    required bool selected,
  }) {
    return GestureDetector(
      onTap: () => setState(
          () => _draft = _draft.copyWith(coupleType: value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppTheme.accent : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.accent,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: 도시 설정 ───────────────────────────────────
  Widget _buildStep2() {
    final isTogether = _draft.coupleType == 'together';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '어디에 계세요?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isTogether
                ? '날씨 정보와 교통 안내에 사용돼요'
                : '두 분의 날씨와 교통 안내에 사용돼요',
            style:
                const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [AppTheme.subtleShadow],
            ),
            child: Column(
              children: [
                RegionSelectorWidget(
                  label: isTogether ? '우리 동네' : '내 도시',
                  selectedProvince:
                      getProvinceOfCity(_draft.myCity ?? ''),
                  selectedCity: _draft.myCity,
                  onProvinceChanged: (_) {},
                  onCityChanged: (v) {
                    final station = getBestStation(v);
                    setState(() {
                      _draft = _draft.copyWith(
                        myCity: v,
                        myStation: station,
                        partnerCity:
                            isTogether ? v : _draft.partnerCity,
                        partnerStation: isTogether
                            ? station
                            : _draft.partnerStation,
                      );
                    });
                  },
                ),
                if (!isTogether) ...[
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  RegionSelectorWidget(
                    label: '애인 도시',
                    selectedProvince:
                        getProvinceOfCity(_draft.partnerCity ?? ''),
                    selectedCity: _draft.partnerCity,
                    onProvinceChanged: (_) {},
                    onCityChanged: (v) {
                      setState(() {
                        _draft = _draft.copyWith(
                          partnerCity: v,
                          partnerStation: getBestStation(v),
                        );
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              OutlinedButton(
                onPressed: _prev,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('이전'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('다음', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3: 근무 형태 + 근무 시간 ─────────────────────────
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '어떤 형태로 일하세요?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '근무 형태에 맞는 일정 관리를 도와드려요',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),
          ..._patterns.map((opt) {
            final selected = _draft.workPattern == opt.$1;
            return GestureDetector(
              onTap: () => setState(() {
                _draft = _draft.copyWith(
                  workPattern: opt.$1,
                  shiftTimes: getShiftDefaults(opt.$1),
                );
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
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
                    Text(opt.$2,
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        opt.$3,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.accent
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent, size: 20),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          const Text(
            '근무 시간 설정',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            '시간을 탭해서 수정할 수 있어요',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          ShiftTimeEditor(
            shiftTimes: _draft.shiftTimes,
            onChanged: (updated) =>
                setState(() => _draft = _draft.copyWith(shiftTimes: updated)),
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              OutlinedButton(
                onPressed: _prev,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('이전'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _complete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('시작하기 🎉',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

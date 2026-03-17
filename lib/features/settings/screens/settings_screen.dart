import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../couple/services/couple_service.dart';
import '../../notifications/screens/notification_settings_screen.dart';
import '../../profile/models/couple_profile.dart';
import '../../profile/services/profile_service.dart';
import '../../profile/data/shift_defaults.dart' show getShiftDefaults, shiftLabel;
import '../../profile/models/shift_time.dart';
import '../../onboarding/widgets/city_selector_widget.dart';
import '../../onboarding/widgets/shift_time_editor.dart';
import '../../auth/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _myNickname;
  String? _partnerNickname;
  DateTime? _startedAt;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _coupleId;

  // 프로필 설정
  CoupleProfile? _profile;
  final _profileService = ProfileService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 열릴 때 데이터 갱신 (커플 연결 시)
    if (_hasLoadedOnce) {
      _loadData();
    }
    _hasLoadedOnce = true;
  }

  Future<void> _changeStartedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt ?? DateTime(2020, 1, 1),
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (date != null && _coupleId != null) {
      try {
        await supabase
            .from('couples')
            .update({'started_at': date.toIso8601String().split('T')[0]})
            .eq('id', _coupleId!);
        if (mounted) {
          setState(() => _startedAt = date);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('연애 시작일이 변경되었습니다')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
        }
      }
    }
  }

  Future<void> _editProfile(bool isMyProfile) async {
    final controller = TextEditingController(
      text: isMyProfile ? _myNickname : _partnerNickname,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMyProfile ? '내 이름 변경' : '내 애인 이름 설정'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '이름을 입력하세요'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        final userId = supabase.auth.currentUser!.id;

        if (isMyProfile) {
          await supabase
              .from('profiles')
              .update({'nickname': newName})
              .eq('id', userId);
          setState(() => _myNickname = newName);
        } else {
          // 파트너 닉네임 설정 (다른 사용자의 프로필 업데이트)
          if (_coupleId != null) {
            final couple = await supabase
                .from('couples')
                .select('user1_id, user2_id')
                .eq('id', _coupleId!)
                .single();
            final partnerId = couple['user1_id'] == userId
                ? couple['user2_id']
                : couple['user1_id'];
            if (partnerId != null) {
              await supabase
                  .from('profiles')
                  .update({'nickname': newName})
                  .eq('id', partnerId);
              setState(() => _partnerNickname = newName);
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이름이 변경되었습니다')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
        }
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // 내 프로필 조회
      Map<String, dynamic>? profile;
      try {
        profile = await supabase
            .from('profiles')
            .select('nickname, couple_id')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }

      // 프로필이 없으면 생성 (트리거가 작동 안 했을 경우 대비)
      if (profile == null) {
        final nickname =
            supabase.auth.currentUser!.userMetadata?['nickname'] as String? ??
            '사용자';
        await supabase.from('profiles').insert({
          'id': userId,
          'nickname': nickname,
        });
        _myNickname = nickname;
        _coupleId = null;
      } else {
        _myNickname = profile['nickname'] as String?;
        _coupleId = profile['couple_id'] as String?;
      }

      // 커플 정보 로드
      if (_coupleId != null) {
        final couple = await supabase
            .from('couples')
            .select('started_at, user1_id, user2_id')
            .eq('id', _coupleId!)
            .maybeSingle();

        if (couple != null) {
          if (couple['started_at'] != null) {
            _startedAt = DateTime.parse(couple['started_at'] as String);
          }
          final partnerId = couple['user1_id'] == userId
              ? couple['user2_id']
              : couple['user1_id'];

          if (partnerId != null && (partnerId as String).isNotEmpty) {
            final partner = await supabase
                .from('profiles')
                .select('nickname')
                .eq('id', partnerId)
                .maybeSingle();
            _partnerNickname = partner?['nickname'] as String?;
          } else {
            _partnerNickname = null;
          }
        } else {
          _partnerNickname = null;
          _startedAt = null;
        }
      }
      // 프로필 설정 로드
      _profile = await _profileService.loadMyProfile();
      if (_profile != null) FeatureFlagService().refresh(_profile!);
    } catch (e) {
      debugPrint('Settings _loadData error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWorkPattern(String pattern) async {
    final updated = (_profile ?? const CoupleProfile(
      distanceType: 'same_city', workPattern: 'office', shiftTimes: [],
    )).copyWith(
      workPattern: pattern,
      shiftTimes: getShiftDefaults(pattern),
    );
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
  }

  Future<void> _saveShiftTimes(List<ShiftTime> times) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(shiftTimes: times);
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
  }

  Future<void> _saveDistanceType(String distanceType) async {
    final updated = (_profile ?? const CoupleProfile(
      distanceType: 'same_city', workPattern: 'office', shiftTimes: [],
    )).copyWith(distanceType: distanceType);
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
  }

  Future<void> _saveCityStation({
    String? myCity,
    String? myStation,
    String? partnerCity,
    String? partnerStation,
  }) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(
      myCity: myCity,
      myStation: myStation,
      partnerCity: partnerCity,
      partnerStation: partnerStation,
    );
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
  }

  void _showWorkPatternPicker() {
    const patterns = [
      ('shift_3', '👩‍⚕️', '간호사 / 의료직 3교대'),
      ('shift_2', '🔄', '교대 근무 2교대'),
      ('office', '💼', '일반 직장인 (주5일)'),
      ('other', '🎨', '기타 / 프리랜서'),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '근무 유형 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...patterns.map((opt) {
                final selected = (_profile?.workPattern ?? 'office') == opt.$1;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveWorkPattern(opt.$1);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withValues(alpha: 0.08)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppTheme.primary : AppTheme.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(opt.$2, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(
                          opt.$3,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showDistancePicker() {
    const distanceOptions = [
      ('same_city', '🏙️', '같은 도시 (30분 이내)'),
      ('near', '🚌', '근거리 (1~2시간)'),
      ('long_distance', '🚆', '장거리 (다른 도시)'),
    ];

    // 시트 내부 임시 상태
    String selectedType = _profile?.distanceType ?? 'same_city';
    String? tempMyCity = _profile?.myCity;
    String? tempMyStation = _profile?.myStation;
    String? tempPartnerCity = _profile?.partnerCity;
    String? tempPartnerStation = _profile?.partnerStation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '거리 유형 선택',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ...distanceOptions.map((opt) {
                  final isSelected = selectedType == opt.$1;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedType = opt.$1),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.08)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(opt.$2, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Text(
                            opt.$3,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                // 장거리 선택 시 도시/역 편집
                if (selectedType == 'long_distance') ...[
                  const SizedBox(height: 8),
                  CitySelectorWidget(
                    label: '내 도시 / 역',
                    selectedCity: tempMyCity,
                    selectedStation: tempMyStation,
                    onCityChanged: (v) => setSheet(() {
                      tempMyCity = v;
                      tempMyStation = null;
                    }),
                    onStationChanged: (v) =>
                        setSheet(() => tempMyStation = v),
                  ),
                  const SizedBox(height: 12),
                  CitySelectorWidget(
                    label: '파트너 도시 / 역',
                    selectedCity: tempPartnerCity,
                    selectedStation: tempPartnerStation,
                    onCityChanged: (v) => setSheet(() {
                      tempPartnerCity = v;
                      tempPartnerStation = null;
                    }),
                    onStationChanged: (v) =>
                        setSheet(() => tempPartnerStation = v),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // distanceType 저장
                      await _saveDistanceType(selectedType);
                      // 장거리인 경우 도시/역도 저장
                      if (selectedType == 'long_distance') {
                        await _saveCityStation(
                          myCity: tempMyCity,
                          myStation: tempMyStation,
                          partnerCity: tempPartnerCity,
                          partnerStation: tempPartnerStation,
                        );
                      }
                    },
                    child: const Text('저장', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _breakUp() async {
    if (_coupleId == null) return;

    // 1단계: 경고 다이얼로그
    final goNext = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('💔', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              '헤어지기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '헤어지면 아래 데이터가 모두 삭제되며\n절대 복구할 수 없어요.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            _warnItem('📅 우리가 함께 쌓은 모든 일정'),
            _warnItem('💬 일정에 남긴 댓글'),
            _warnItem('🎨 색상 매핑 설정'),
            _warnItem('💑 커플 연결 정보'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '이 작업은 두 사람 모두에게 적용되며,\n되돌릴 수 없습니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('계속하기'),
          ),
        ],
      ),
    );

    if (goNext != true || !mounted) return;

    // 2단계: 최종 확인 (텍스트 입력)
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '정말 헤어지실 건가요?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '확인을 위해 아래에 "헤어지기"를 입력해주세요.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '헤어지기',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                '취소',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmController.text.trim() == '헤어지기'
                    ? Colors.red
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: confirmController.text.trim() == '헤어지기'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('헤어지기'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // 실제 삭제 처리
    setState(() => _isLoading = true);
    try {
      await CoupleService().disconnectCouple(_coupleId!);
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('💔', style: TextStyle(fontSize: 48)),
                SizedBox(height: 16),
                Text(
                  '연결이 해제되었습니다',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '다시 로그인하면\n새 파트너와 연결할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        await supabase.auth.signOut();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Widget _warnItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // 1단계: 경고 확인
    final goNext = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('⚠️', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('회원 탈퇴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('탈퇴하면 아래 데이터가 모두 삭제되며\n절대 복구할 수 없어요.',
                style: TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
            _warnItem('📅 모든 일정 및 댓글'),
            _warnItem('🎨 색상 매핑 설정'),
            _warnItem('💑 커플 연결 정보'),
            _warnItem('👤 계정 및 프로필'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Text('탈퇴 후 동일 이메일로 재가입해도\n데이터는 복구되지 않습니다.',
                  style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('계속하기'),
          ),
        ],
      ),
    );

    if (goNext != true || !mounted) return;

    // 2단계: "탈퇴하기" 입력 최종 확인
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('정말 탈퇴하실 건가요?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('확인을 위해 아래에 "탈퇴하기"를 입력해주세요.',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '탈퇴하기',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  ),
                ),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmController.text.trim() == '탈퇴하기'
                    ? Colors.red
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: confirmController.text.trim() == '탈퇴하기'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('탈퇴하기'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // 실제 탈퇴 처리
    setState(() => _isLoading = true);
    try {
      await AuthService().deleteAccount();
      // signOut 후 AppRouter가 자동으로 LoginScreen으로 전환
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 처리 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃', style: TextStyle(fontSize: 16)),
        content: const Text('로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirm == true) await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // 커플 정보 섹션
                _buildSectionTitle('커플 정보'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 닉네임
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _myNickname ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '&',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                          Text(
                            _partnerNickname ?? '연결 대기 중',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: _partnerNickname != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _coupleId != null ? _changeStartedAt : null,
                            child: Row(mainAxisSize: MainAxisSize.min),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 연애 시작일
                      GestureDetector(
                        onTap: _coupleId != null ? _changeStartedAt : null,
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _startedAt != null
                                  ? '연애 시작일: ${_startedAt!.year}년 ${_startedAt!.month}월 ${_startedAt!.day}일'
                                  : '연애 시작일 미설정 (터치하여 설정)',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                      if (_coupleId != null) ...[
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _breakUp,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.heart_broken_outlined,
                                size: 16,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '헤어지기',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 프로필 설정
                _buildSectionTitle('프로필 설정'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.person_outline,
                          color: AppTheme.textPrimary,
                        ),
                        title: const Text('내 이름 변경'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                        onTap: () => _editProfile(true),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.favorite_border,
                          color: AppTheme.accent,
                        ),
                        title: const Text('내 애인 이름 설정'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                        onTap: () => _editProfile(false),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 근무 설정
                _buildSectionTitle('근무 설정'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.work_outline, color: AppTheme.textPrimary),
                      title: const Text('근무 유형'),
                      trailing: Text(
                        shiftLabel(_profile?.workPattern ?? 'office'),
                        style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary,
                        ),
                      ),
                      onTap: () => _showWorkPatternPicker(),
                    ),
                    if (_profile != null &&
                        (_profile!.workPattern == 'shift_3' ||
                            _profile!.workPattern == 'shift_2')) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('근무 시간',
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                )),
                            const SizedBox(height: 10),
                            ShiftTimeEditor(
                              shiftTimes: _profile!.shiftTimes,
                              onChanged: _saveShiftTimes,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),

                const SizedBox(height: 32),

                // 거리 설정 [GAP-FIX]
                _buildSectionTitle('거리 설정'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.map_outlined,
                          color: AppTheme.textPrimary,
                        ),
                        title: const Text('거리 유형'),
                        trailing: Text(
                          _distanceTypeLabel(_profile?.distanceType ?? 'same_city'),
                          style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary,
                          ),
                        ),
                        onTap: _showDistancePicker,
                      ),
                      if (_profile != null &&
                          _profile!.distanceType == 'long_distance') ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.textPrimary,
                          ),
                          title: const Text('내 도시 / 역'),
                          trailing: Text(
                            [_profile!.myCity, _profile!.myStation]
                                .whereType<String>()
                                .join(' · ')
                                .isNotEmpty
                                ? [_profile!.myCity, _profile!.myStation]
                                    .whereType<String>()
                                    .join(' · ')
                                : '미설정',
                            style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary,
                            ),
                          ),
                          onTap: _showDistancePicker,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppTheme.accent,
                          ),
                          title: const Text('파트너 도시 / 역'),
                          trailing: Text(
                            [_profile!.partnerCity, _profile!.partnerStation]
                                .whereType<String>()
                                .join(' · ')
                                .isNotEmpty
                                ? [_profile!.partnerCity, _profile!.partnerStation]
                                    .whereType<String>()
                                    .join(' · ')
                                : '미설정',
                            style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary,
                            ),
                          ),
                          onTap: _showDistancePicker,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 앱 설정
                _buildSectionTitle('앱 설정'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_outlined,
                          color: AppTheme.textPrimary,
                        ),
                        title: const Text('알림 설정'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.info_outline,
                          color: AppTheme.textPrimary,
                        ),
                        title: const Text('앱 버전'),
                        trailing: const Text(
                          'v1.0.0',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.description_outlined,
                          color: AppTheme.textPrimary,
                        ),
                        title: const Text('서비스 이용약관'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('준비 중입니다.')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.privacy_tip_outlined,
                          color: AppTheme.textPrimary,
                        ),
                        title: const Text('개인정보 처리방침'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('준비 중입니다.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 로그아웃
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    '로그아웃',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),

                // 계정 탈퇴
                TextButton(
                  onPressed: _deleteAccount,
                  child: const Text(
                    '회원 탈퇴',
                    style: TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _distanceTypeLabel(String type) {
    switch (type) {
      case 'same_city':
        return '같은 도시';
      case 'near':
        return '근거리';
      case 'long_distance':
        return '장거리';
      default:
        return type;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

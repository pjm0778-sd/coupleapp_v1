import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../../core/profile_change_notifier.dart';
import '../../couple/services/couple_service.dart';
import '../../notifications/screens/notification_settings_screen.dart';
import '../../profile/models/couple_profile.dart';
import '../../profile/services/profile_service.dart';
import '../../profile/data/shift_defaults.dart'
    show getShiftDefaults, shiftLabel;
import '../../profile/data/city_station_data.dart'
    show getBestStation, getProvinceOfCity, getCitiesInProvince, getProvinces;
import '../../../core/holiday_service.dart';
import '../../calendar/services/schedule_service.dart';
import '../../profile/models/shift_time.dart';
import '../../onboarding/widgets/shift_time_editor.dart';
import '../../onboarding/widgets/region_selector_widget.dart';
import '../../auth/services/auth_service.dart';
import '../../couple/screens/couple_connect_screen.dart';

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

  // 일반 직장인 근무 색상 (세션 내 유지)
  String _officeWorkColorHex = '#4CAF50';

  static const _presetWorkColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE91E63),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFF44336),
    Color(0xFF00BCD4),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFFFEB3B),
    Color(0xFF8BC34A),
    Color(0xFF3F51B5),
  ];

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF4CAF50);
    }
  }

  Future<void> _pickOfficeWorkColor() async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('근무 색상 선택'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _presetWorkColors.map((c) {
            final hex =
                '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
            final isSelected = _officeWorkColorHex.toUpperCase() == hex;
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, c),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black87 : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (picked != null) {
      final hex =
          '#${picked.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      setState(() => _officeWorkColorHex = hex);
    }
  }

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
        await CoupleService().updateStartedAt(_coupleId!, date);
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
        if (isMyProfile) {
          await _profileService.saveNickname(newName);
          if (mounted) setState(() => _myNickname = newName);
        } else {
          // 파트너 닉네임 설정 (다른 사용자의 프로필 업데이트)
          if (_coupleId != null) {
            await _profileService.savePartnerNickname(
              coupleId: _coupleId!,
              nickname: newName,
            );
            if (mounted) setState(() => _partnerNickname = newName);
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
      // 내 프로필 기본 정보 로드 (없으면 자동 생성)
      final basic = await _profileService.loadBasicProfile();
      _myNickname = basic.nickname;
      _coupleId = basic.coupleId;

      // 커플 정보 로드
      if (_coupleId != null) {
        final coupleInfo = await CoupleService().getCoupleInfo();
        if (coupleInfo != null) {
          if (coupleInfo['started_at'] != null) {
            _startedAt = DateTime.parse(coupleInfo['started_at'] as String);
          }
          _partnerNickname = await _profileService.loadPartnerNickname(
            _coupleId!,
          );
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
    final updated =
        (_profile ??
                const CoupleProfile(
                  distanceType: 'same_city',
                  workPattern: 'office',
                  shiftTimes: [],
                ))
            .copyWith(
              workPattern: pattern,
              shiftTimes: getShiftDefaults(pattern),
            );
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
    ProfileChangeNotifier().notify();
  }

  Future<void> _editWorkTitle() async {
    if (_profile == null || _profile!.shiftTimes.isEmpty) return;
    final current = _profile!.shiftTimes.first;
    final controller = TextEditingController(text: current.label);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('근무 제목 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '예: 근무, 출근, 업무'),
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

    if (newTitle != null && newTitle.isNotEmpty) {
      final updated = [
        current.copyWith(label: newTitle),
        ..._profile!.shiftTimes.skip(1),
      ];
      await _saveShiftTimes(updated);
    }
  }

  Future<void> _applyOfficeSchedulesThisMonth() async {
    if (_profile == null || _coupleId == null) return;
    if (_profile!.workPattern != 'office') return;
    if (_profile!.shiftTimes.isEmpty) return;

    final shift = _profile!.shiftTimes.first;
    final now = DateTime.now();

    // 이번달 공휴일 목록 수집
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final holidayDates = <String>[];
    for (
      var d = firstDay;
      !d.isAfter(lastDay);
      d = d.add(const Duration(days: 1))
    ) {
      if (HolidayService().getHolidays(d).isNotEmpty) {
        holidayDates.add(d.toIso8601String().split('T')[0]);
      }
    }

    // 등록될 평일 수 미리 계산 (확인 다이얼로그용)
    int weekdayCount = 0;
    for (
      var d = firstDay;
      !d.isAfter(lastDay);
      d = d.add(const Duration(days: 1))
    ) {
      if (d.weekday >= DateTime.monday && d.weekday <= DateTime.friday) {
        final dateStr = d.toIso8601String().split('T')[0];
        if (!holidayDates.contains(dateStr)) weekdayCount++;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('이번달 근무 일정 등록'),
        content: Text(
          '${now.month}월 평일 $weekdayCount일에\n"${shift.label}" 일정을 등록합니다.\n'
          '(${shift.startHour.toString().padLeft(2, '0')}:${shift.startMinute.toString().padLeft(2, '0')} ~ '
          '${shift.endHour.toString().padLeft(2, '0')}:${shift.endMinute.toString().padLeft(2, '0')})\n\n'
          '기존에 같은 날짜에 일정이 있으면 중복으로 추가될 수 있습니다.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('등록하기'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final count = await ScheduleService().bulkInsertOfficeSchedules(
        coupleId: _coupleId!,
        title: shift.label,
        startTime: shift.startTime,
        endTime: shift.endTime,
        holidayDates: holidayDates,
        colorHex: _officeWorkColorHex,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$count일의 근무 일정이 등록되었습니다.')));
        ProfileChangeNotifier().notify();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('등록 실패: $e')));
      }
    }
  }

  Future<void> _saveShiftTimes(List<ShiftTime> times) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(shiftTimes: times);
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
    ProfileChangeNotifier().notify();
  }

  Future<void> _saveWeatherCity({String? myCity, String? partnerCity}) async {
    final current =
        _profile ??
        const CoupleProfile(
          distanceType: 'same_city',
          workPattern: 'office',
          shiftTimes: [],
        );
    final updated = current.copyWith(
      myCity: myCity ?? current.myCity,
      partnerCity: partnerCity ?? current.partnerCity,
    );
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
    ProfileChangeNotifier().notify();
  }

  void _showWeatherCityPicker({required bool isMe}) {
    final provinces = getProvinces();
    String? selectedProvince;
    String? selectedCity = isMe ? _profile?.myCity : _profile?.partnerCity;
    if (selectedCity != null) {
      selectedProvince = provinces.firstWhere(
        (p) => getCitiesInProvince(p).contains(selectedCity),
        orElse: () => provinces.first,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
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
                Text(
                  isMe ? '내 위치 도시 설정' : '파트너 위치 도시 설정',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                // 도 선택
                DropdownButtonFormField<String>(
                  initialValue: selectedProvince,
                  decoration: InputDecoration(
                    labelText: '도/광역시',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: provinces
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setSheet(() {
                    selectedProvince = v;
                    selectedCity = null;
                  }),
                ),
                const SizedBox(height: 12),
                // 시/군 선택
                if (selectedProvince != null)
                  DropdownButtonFormField<String>(
                    initialValue: selectedCity,
                    decoration: InputDecoration(
                      labelText: '시/군',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: getCitiesInProvince(selectedProvince!)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setSheet(() => selectedCity = v),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCity == null
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            if (isMe) {
                              await _saveWeatherCity(myCity: selectedCity);
                            } else {
                              await _saveWeatherCity(partnerCity: selectedCity);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCoupleType(String coupleType) async {
    final updated =
        (_profile ??
                const CoupleProfile(
                  distanceType: 'same_city',
                  workPattern: 'office',
                  shiftTimes: [],
                ))
            .copyWith(coupleType: coupleType);
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
    ProfileChangeNotifier().notify();
  }

  Future<void> _saveDistanceType(String distanceType) async {
    final updated =
        (_profile ??
                const CoupleProfile(
                  distanceType: 'same_city',
                  workPattern: 'office',
                  shiftTimes: [],
                ))
            .copyWith(distanceType: distanceType);
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
    ProfileChangeNotifier().notify();
  }

  Future<void> _saveCityStation({
    String? myCity,
    String? partnerCity,
    String? partnerStation,
  }) async {
    if (_profile == null) return;
    // 내 도시 → 최적 역 자동 선택
    final autoMyStation = myCity != null
        ? getBestStation(myCity)
        : _profile!.myStation;
    // 파트너 도시 → 역 미지정 시 자동 선택
    final autoPartnerStation =
        partnerStation ??
        (partnerCity != null
            ? getBestStation(partnerCity)
            : _profile!.partnerStation);
    final updated = _profile!.copyWith(
      myCity: myCity ?? _profile!.myCity,
      myStation: autoMyStation,
      partnerCity: partnerCity ?? _profile!.partnerCity,
      partnerStation: autoPartnerStation,
    );
    await _profileService.saveProfile(updated);
    FeatureFlagService().refresh(updated);
    if (mounted) setState(() => _profile = updated);
    ProfileChangeNotifier().notify();
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.accentLight : AppTheme.surface,
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
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
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

    String selectedType = _profile?.distanceType ?? 'same_city';
    String? tempMyCity = _profile?.myCity;
    String? tempMyProvince = tempMyCity != null
        ? getProvinceOfCity(tempMyCity)
        : null;
    String? tempPartnerCity = _profile?.partnerCity;
    String? tempPartnerProvince = tempPartnerCity != null
        ? getProvinceOfCity(tempPartnerCity)
        : null;
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
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentLight
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.border,
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
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                // 장거리: 내 지역(도/시·군), 파트너 지역(도/시·군)
                if (selectedType == 'long_distance') ...[
                  const SizedBox(height: 16),
                  // 내 지역 — 역 선택 없음, 자동 선택
                  RegionSelectorWidget(
                    label: '내 출발 도시',
                    selectedProvince: tempMyProvince,
                    selectedCity: tempMyCity,
                    onProvinceChanged: (v) =>
                        setSheet(() => tempMyProvince = v),
                    onCityChanged: (v) => setSheet(() => tempMyCity = v),
                  ),
                  const SizedBox(height: 16),
                  // 파트너 지역 — 역 자동 선택 (미리보기 표시)
                  RegionSelectorWidget(
                    label: '애인 출발 도시',
                    selectedProvince: tempPartnerProvince,
                    selectedCity: tempPartnerCity,
                    onProvinceChanged: (v) =>
                        setSheet(() => tempPartnerProvince = v),
                    onCityChanged: (v) {
                      setSheet(() {
                        tempPartnerCity = v;
                        tempPartnerStation = null; // 도시 바뀌면 역 초기화
                      });
                    },
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
                      await _saveDistanceType(selectedType);
                      if (selectedType == 'long_distance') {
                        await _saveCityStation(
                          myCity: tempMyCity,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '다시 로그인하면\n새 파트너와 연결할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0x99FFFFFF),
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
        await AuthService().signOut();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('처리 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Widget _buildCoupleTypeOption({
    required String value,
    required String emoji,
    required String label,
    required String description,
    required bool selected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _saveCoupleType(value),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentLight : AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  String _formatDeleteAccountError(Object error) {
    final message = error.toString();

    if (message.contains('profiles_id_fkey')) {
      return '현재 Supabase DB의 profiles 외래키 설정이 오래돼서 탈퇴가 막히고 있어요. 최신 마이그레이션을 적용하면 해결됩니다.';
    }

    if (message.contains('remove owned storage files first')) {
      return '이 계정이 소유한 Supabase Storage 파일이 남아 있어요. Supabase 대시보드의 Storage에서 해당 파일을 먼저 삭제한 뒤 다시 시도해주세요.';
    }

    if (message.contains('Database error deleting user')) {
      return 'Supabase에서 계정 삭제를 막고 있어요. 보통 Storage 소유 파일이나 남아 있는 참조 데이터가 원인입니다. 대시보드의 Storage와 Authentication > Users를 확인해주세요.';
    }

    return '탈퇴 처리 중 오류가 발생했습니다: $message';
  }

  Future<void> _deleteAccount() async {
    // 1단계: 경고 확인
    final goNext = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('⚠️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              '회원 탈퇴',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '탈퇴하면 아래 데이터가 모두 삭제되며\n절대 복구할 수 없어요.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
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
              child: const Text(
                '탈퇴 후 동일 이메일로 재가입해도\n데이터는 복구되지 않습니다.',
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

    // 2단계: "탈퇴하기" 입력 최종 확인
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
            '정말 탈퇴하실 건가요?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '확인을 위해 아래에 "탈퇴하기"를 입력해주세요.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '탈퇴하기',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
              child: const Text(
                '취소',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmController.text.trim() == '탈퇴하기'
                    ? Colors.red
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_formatDeleteAccountError(e))));
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
    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text(
          '설정',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: AppTheme.pageGradient)),
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              : Theme(
                  data: Theme.of(context).copyWith(
                    listTileTheme: const ListTileThemeData(
                      textColor: AppTheme.textPrimary,
                      iconColor: AppTheme.textSecondary,
                    ),
                    dividerTheme: const DividerThemeData(
                      color: AppTheme.border,
                      thickness: 1,
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
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
                          boxShadow: const [AppTheme.subtleShadow],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 닉네임
                            Row(
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _myNickname ?? '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '&',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    _partnerNickname ?? '연결 대기 중',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: _partnerNickname != null
                                          ? AppTheme.textPrimary
                                          : AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _coupleId != null
                                      ? _changeStartedAt
                                      : null,
                                  child: Row(mainAxisSize: MainAxisSize.min),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // 연애 시작일
                            GestureDetector(
                              onTap: _coupleId != null
                                  ? _changeStartedAt
                                  : null,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _startedAt != null
                                          ? '연애 시작일: ${_startedAt!.year}년 ${_startedAt!.month}월 ${_startedAt!.day}일'
                                          : '연애 시작일 미설정 (터치하여 설정)',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                            if (_coupleId == null) ...[
                              const SizedBox(height: 20),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CoupleConnectScreen(),
                                    ),
                                  );
                                  _loadData();
                                },
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite_outline,
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '커플 연동하기',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

                      // 연애 스타일
                      _buildSectionTitle('연애 스타일'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: const [AppTheme.subtleShadow],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '우리 커플의 연애 유형을 선택하세요.\n선택에 따라 홈 화면 기능이 달라져요.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _buildCoupleTypeOption(
                                  value: 'together',
                                  emoji: '🏠',
                                  label: '매일 함께',
                                  description: '같이 살거나\n매일 만나는 커플',
                                  selected:
                                      (_profile?.coupleType ?? 'distance') ==
                                      'together',
                                ),
                                const SizedBox(width: 10),
                                _buildCoupleTypeOption(
                                  value: 'distance',
                                  emoji: '💌',
                                  label: '설레는 거리',
                                  description: '떨어져 지내며\n만남이 더 특별한 커플',
                                  selected:
                                      (_profile?.coupleType ?? 'distance') ==
                                      'distance',
                                ),
                              ],
                            ),
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
                          boxShadow: const [AppTheme.subtleShadow],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.person_outline,
                                color: AppTheme.textSecondary,
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
                                color: AppTheme.primary,
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
                          boxShadow: const [AppTheme.subtleShadow],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.work_outline,
                                color: AppTheme.textSecondary,
                              ),
                              title: const Text('근무 유형'),
                              trailing: SizedBox(
                                width: 110,
                                child: Text(
                                  shiftLabel(_profile?.workPattern ?? 'office'),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              onTap: () => _showWorkPatternPicker(),
                            ),
                            if (_profile != null) ...[
                              // 일반 직장인: 근무 제목 편집
                              if (_profile!.workPattern == 'office') ...[
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(
                                    Icons.edit_outlined,
                                    color: AppTheme.textSecondary,
                                  ),
                                  title: const Text('근무 제목'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 96,
                                        child: Text(
                                          _profile!.shiftTimes.isNotEmpty
                                              ? _profile!.shiftTimes.first.label
                                              : '근무',
                                          textAlign: TextAlign.right,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ],
                                  ),
                                  onTap: _editWorkTitle,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: _hexToColor(_officeWorkColorHex),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  title: const Text('근무 색상'),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppTheme.textSecondary,
                                  ),
                                  onTap: _pickOfficeWorkColor,
                                ),
                              ],
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '근무 시간',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ShiftTimeEditor(
                                      shiftTimes: _profile!.shiftTimes,
                                      onChanged: _saveShiftTimes,
                                    ),
                                    // 일반 직장인: 이번달 적용 버튼
                                    if (_profile!.workPattern == 'office') ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _applyOfficeSchedulesThisMonth,
                                          icon: const Icon(
                                            Icons.calendar_month_outlined,
                                            size: 18,
                                          ),
                                          label: const Text('이번달에 적용하기'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 교통 정보
                      _buildSectionTitle('교통 정보'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: const [AppTheme.subtleShadow],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.map_outlined,
                                color: AppTheme.textSecondary,
                              ),
                              title: const Text('연애 거리'),
                              trailing: SizedBox(
                                width: 120,
                                child: Text(
                                  _distanceTypeLabel(
                                    _profile?.distanceType ?? 'same_city',
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
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
                                  color: AppTheme.textSecondary,
                                ),
                                title: const Text('내 출발역'),
                                trailing: SizedBox(
                                  width: 140,
                                  child: Text(
                                    [_profile!.myCity, _profile!.myStation]
                                            .whereType<String>()
                                            .join(' · ')
                                            .isNotEmpty
                                        ? [
                                            _profile!.myCity,
                                            _profile!.myStation,
                                          ].whereType<String>().join(' · ')
                                        : '미설정',
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                onTap: _showDistancePicker,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppTheme.primary,
                                ),
                                title: const Text('애인 출발역'),
                                trailing: SizedBox(
                                  width: 140,
                                  child: Text(
                                    [
                                              _profile!.partnerCity,
                                              _profile!.partnerStation,
                                            ]
                                            .whereType<String>()
                                            .join(' · ')
                                            .isNotEmpty
                                        ? [
                                            _profile!.partnerCity,
                                            _profile!.partnerStation,
                                          ].whereType<String>().join(' · ')
                                        : '미설정',
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                onTap: _showDistancePicker,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 날씨 지역
                      _buildSectionTitle('날씨 지역'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: const [AppTheme.subtleShadow],
                        ),
                        child: Column(
                          children: [
                            if ((_profile?.coupleType ?? 'distance') ==
                                'together') ...[
                              ListTile(
                                leading: const Icon(
                                  Icons.wb_sunny_outlined,
                                  color: Color(0xFF1976D2),
                                ),
                                title: const Text('우리 동네'),
                                trailing: Text(
                                  _profile?.myCity ?? '미설정',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _profile?.myCity != null
                                        ? AppTheme.textSecondary
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                                onTap: () => _showWeatherCityPicker(isMe: true),
                              ),
                            ] else ...[
                              ListTile(
                                leading: const Icon(
                                  Icons.wb_sunny_outlined,
                                  color: Color(0xFF1976D2),
                                ),
                                title: const Text('내 도시'),
                                trailing: Text(
                                  _profile?.myCity ?? '미설정',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _profile?.myCity != null
                                        ? AppTheme.textSecondary
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                                onTap: () => _showWeatherCityPicker(isMe: true),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.favorite_border,
                                  color: AppTheme.primary,
                                ),
                                title: const Text('애인 도시'),
                                trailing: Text(
                                  _profile?.partnerCity ?? '미설정',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _profile?.partnerCity != null
                                        ? AppTheme.textSecondary
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                                onTap: () =>
                                    _showWeatherCityPicker(isMe: false),
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
                          boxShadow: const [AppTheme.subtleShadow],
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.notifications_outlined,
                                color: AppTheme.textSecondary,
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
                                color: AppTheme.textSecondary,
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
                                color: AppTheme.textSecondary,
                              ),
                              title: const Text('서비스 이용약관 및 개인정보 처리방침'),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppTheme.textSecondary,
                              ),
                              onTap: () async {
                                final uri = Uri.parse(
                                  'https://cooing-vacuum-46e.notion.site/c9f4e816cbe383ffbb5d01df0b220c98',
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
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
                            color: AppTheme.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 1.8,
          height: 1.0,
        ),
      ),
    );
  }
}

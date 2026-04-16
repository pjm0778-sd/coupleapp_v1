import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../calendar/services/schedule_service.dart';
import '../../profile/models/shift_time.dart';
import '../../profile/services/profile_service.dart';
import '../../settings/screens/settings_screen.dart';
import 'ocr_review_screen.dart';
import 'google_calendar_screen.dart';
import 'excel_import_screen.dart';

class AutoRegistrationScreen extends StatefulWidget {
  const AutoRegistrationScreen({super.key});

  @override
  State<AutoRegistrationScreen> createState() => _AutoRegistrationScreenState();
}

class _AutoRegistrationScreenState extends State<AutoRegistrationScreen>
    with SingleTickerProviderStateMixin {
  String? _myUserId;
  String? _coupleId;
  String? _partnerId;
  String? _partnerNickname;
  List<ShiftTime> _shiftTimes = [];
  bool _isUploading = false;
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _myUserId = supabase.auth.currentUser?.id;
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showShiftTimeWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFCBA258)),
            SizedBox(width: 8),
            Text('근무 시간 설정을 확인하세요', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          '설정에서 근무 형태(근무 시간)를 등록하면\nOCR로 가져온 일정에 출근·퇴근 시간이\n자동으로 입력됩니다.\n\n아직 설정하지 않았다면 설정 화면에서\n먼저 근무 형태를 등록해 주세요.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: const Text(
              '설정하러 가기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _init() async {
    // 교대 시간 설정 로드
    final profile = await ProfileService().loadMyProfile();
    if (profile != null && mounted) {
      setState(() => _shiftTimes = profile.shiftTimes);
      if (profile.shiftTimes.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showShiftTimeWarning();
        });
      }
    }

    _coupleId = await ScheduleService().getCoupleId();
    if (_coupleId != null && _myUserId != null) {
      final coupleData = await supabase
          .from('couples')
          .select('user1_id, user2_id')
          .eq('id', _coupleId!)
          .maybeSingle();
      if (coupleData != null) {
        final partnerId = coupleData['user1_id'] == _myUserId
            ? coupleData['user2_id']
            : coupleData['user1_id'];
        if (partnerId != null) {
          final profileData = await supabase
              .from('profiles')
              .select('nickname')
              .eq('id', partnerId)
              .maybeSingle();
          if (mounted) {
            setState(() {
              _partnerId = partnerId?.toString();
              _partnerNickname = profileData?['nickname'] as String?;
            });
          }
        }
      }
    }
  }

  /// OCR 결과에 교대 시간 설정 적용
  /// work_type이 ShiftTime의 shiftType 또는 label과 일치하거나
  /// D*/E*/N* 접두어이면 해당 교대 시간 적용 (DC, EC, NC 등 포함)
  /// 매칭된 항목은 category를 '출근'으로 설정
  List<Map<String, dynamic>> _applyShiftTimes(
    List<Map<String, dynamic>> schedules,
  ) {
    if (_shiftTimes.isEmpty) return schedules;
    return schedules.map((s) {
      final existing = s['start_time'] as String?;
      if (existing != null && existing.isNotEmpty) return s;

      final workType = (s['work_type'] as String? ?? '').trim();
      if (workType.isEmpty) return s;
      final workTypeLower = workType.toLowerCase();

      ShiftTime? matched;

      // 1단계: 정확히 일치 (shiftType or label)
      for (final shift in _shiftTimes) {
        if (shift.shiftType.toLowerCase() == workTypeLower ||
            shift.label.toLowerCase() == workTypeLower) {
          matched = shift;
          break;
        }
      }

      // 2단계: 접두어 매칭 D*/E*/N* (3교대: D→D, E→E, N→N / 2교대: D→day, N→night)
      if (matched == null && workTypeLower.isNotEmpty) {
        final first = workTypeLower[0];
        if (first == 'd') {
          final candidates = _shiftTimes.where(
            (sh) => sh.shiftType == 'D' || sh.shiftType == 'day',
          );
          if (candidates.isNotEmpty) matched = candidates.first;
        } else if (first == 'e') {
          final candidates = _shiftTimes.where((sh) => sh.shiftType == 'E');
          if (candidates.isNotEmpty) matched = candidates.first;
        } else if (first == 'n') {
          final candidates = _shiftTimes.where(
            (sh) => sh.shiftType == 'N' || sh.shiftType == 'night',
          );
          if (candidates.isNotEmpty) matched = candidates.first;
        }
      }

      if (matched == null) return s;

      String pad(int v) => v.toString().padLeft(2, '0');
      final updated = Map<String, dynamic>.from(s);
      updated['start_time'] =
          '${pad(matched.startHour)}:${pad(matched.startMinute)}';
      updated['end_time'] = '${pad(matched.endHour)}:${pad(matched.endMinute)}';
      updated['category'] = '출근';
      return updated;
    }).toList();
  }

  /// 파트너가 있으면 "누구의 일정?" 선택 다이얼로그 표시 후 userId 반환
  Future<String?> _selectTargetUser() async {
    if (_partnerId == null) return _myUserId;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('누구의 일정인가요?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('나의 일정'),
              onTap: () => Navigator.pop(context, 'me'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
              title: Text('${_partnerNickname ?? '파트너'}의 일정'),
              onTap: () => Navigator.pop(context, 'partner'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return null;
    return choice == 'partner' ? _partnerId : _myUserId;
  }

  Future<void> _onOcrPressed() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 2000,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mediaType = image.mimeType ?? 'image/jpeg';
      final now = DateTime.now();

      final response = await supabase.functions.invoke(
        'ocr-schedule',
        body: {
          'imageBase64': base64Image,
          'imageMediaType': mediaType,
          'targetYear': now.year,
          'targetMonth': now.month,
        },
      );

      setState(() => _isUploading = false);

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);

      final schedulesList =
          (data['schedules'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (schedulesList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정을 찾지 못했습니다. 이미지를 확인해주세요')),
          );
        }
        return;
      }

      final ocrYear = data['year'] as int? ?? now.year;
      final ocrMonth = data['month'] as int? ?? now.month;

      if (mounted) {
        final targetUserId = await _selectTargetUser();
        if (targetUserId == null || !mounted) return;

        final mappedSchedules = _applyShiftTimes(schedulesList);

        final saved = await Navigator.push<int>(
          context,
          MaterialPageRoute(
            builder: (_) => OcrReviewScreen(
              schedules: mappedSchedules,
              ocrYear: ocrYear,
              ocrMonth: ocrMonth,
              userId: targetUserId,
              coupleId: _coupleId,
              isGoogleCalendar: false,
            ),
          ),
        );
        if (saved != null && saved > 0 && mounted) {
          if (mounted) Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('분석 실패: $e')));
      }
    }
  }

  void _onGoogleCalendarPressed() async {
    if (_myUserId == null) return;
    final saved = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => GoogleCalendarScreen(
          userId: _myUserId!,
          coupleId: _coupleId,
          partnerId: _partnerId,
          partnerNickname: _partnerNickname,
        ),
      ),
    );
    if (saved != null && saved > 0 && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onExcelImportPressed() async {
    if (_myUserId == null) return;
    final saved = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => ExcelImportScreen(
          myUserId: _myUserId!,
          coupleId: _coupleId,
          partnerId: _partnerId,
          partnerNickname: _partnerNickname,
        ),
      ),
    );
    if (saved != null && saved > 0 && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('일정 가져오기'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: '사진으로'),
            Tab(text: '구글에서'),
            Tab(text: '근무표로'),
          ],
        ),
      ),
      body: Container(
        decoration: AppTheme.pageGradient,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCalendarOcrTab(),
            _buildGoogleCalendarTab(),
            _buildExcelImportTab(),
          ],
        ),
      ),
    );
  }

  // ── 탭 1: 캘린더 앱 사진 분석 ──────────────────────────────
  Widget _buildCalendarOcrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader(
            icon: Icons.phone_android_outlined,
            iconColor: AppTheme.primary,
            title: '사진으로 가져오기',
            description:
                '삼성 캘린더, 아이폰 캘린더, 구글 캘린더 등\n다른 앱의 달력 화면을 캡처하여 가져옵니다.\nAI가 일정을 자동으로 인식합니다.',
          ),
          const SizedBox(height: 28),
          _buildActionCard(
            icon: Icons.image_search_outlined,
            iconColor: AppTheme.primary,
            title: '사진 선택하기',
            subtitle: '갤러리에서 달력 캡처 이미지를 선택하세요',
            badge: 'AI 분석',
            badgeColor: AppTheme.primary,
            isLoading: _isUploading,
            onTap: _isUploading ? null : _onOcrPressed,
          ),
          const SizedBox(height: 20),
          _buildTipBox(
            tips: [
              '달력 전체가 보이도록 캡처해 주세요',
              '글씨가 잘 보일 정도의 해상도면 충분합니다',
              '구글·삼성·아이폰 캘린더 모두 지원합니다',
            ],
          ),
        ],
      ),
    );
  }

  // ── 탭 2: 구글 캘린더 연동 ──────────────────────────────────
  Widget _buildGoogleCalendarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader(
            icon: Icons.calendar_today_outlined,
            iconColor: const Color(0xFF4285F4),
            title: '구글에서 가져오기',
            description: '구글 계정으로 로그인하여\n구글 캘린더의 일정을 직접 가져옵니다.\n가장 정확한 방법입니다.',
          ),
          const SizedBox(height: 28),
          _buildActionCard(
            icon: Icons.login_outlined,
            iconColor: const Color(0xFF4285F4),
            title: '구글 계정으로 가져오기',
            subtitle: '구글 캘린더의 일정을 그대로 불러옵니다',
            badge: '정확도 100%',
            badgeColor: const Color(0xFF34A853),
            isLoading: false,
            onTap: _onGoogleCalendarPressed,
          ),
          const SizedBox(height: 20),
          _buildTipBox(
            tips: [
              '구글 계정 로그인이 필요합니다',
              '가져올 월을 선택할 수 있습니다',
              '중복 일정은 자동으로 처리됩니다',
            ],
          ),
        ],
      ),
    );
  }

  // ── 탭 3: 근무표 불러오기 ──────────────────────────────────
  Widget _buildExcelImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabHeader(
            icon: Icons.table_chart_outlined,
            iconColor: const Color(0xFF1D6F42),
            title: '근무표로 가져오기',
            description:
                '병원·편의점·공장 등의 근무표에서\n내 이름을 지정하면 해당 근무 일정을\n달력에 자동 등록합니다.',
          ),
          const SizedBox(height: 28),
          _buildActionCard(
            icon: Icons.table_chart_outlined,
            iconColor: const Color(0xFF1D6F42),
            title: '근무표 불러오기',
            subtitle: '사진 촬영  ·  엑셀 파일(.xlsx)  ·  Google Sheets',
            badge: 'Premium',
            badgeColor: const Color(0xFFF59E0B),
            isLoading: false,
            onTap: _onExcelImportPressed,
          ),
          const SizedBox(height: 20),
          _buildTipBox(
            tips: [
              '근무표에 표시된 이름과 정확히 일치해야 합니다',
              '인쇄된 근무표는 AI 사진 분석으로 인식합니다',
              '엑셀 파일(.xlsx)을 직접 올리면 정확도 100%입니다',
            ],
          ),
        ],
      ),
    );
  }

  // ── 공통 위젯 ────────────────────────────────────────────────

  Widget _buildTabHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            color: badgeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipBox({required List<String> tips}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.accent),
              SizedBox(width: 6),
              Text(
                '사용 팁',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

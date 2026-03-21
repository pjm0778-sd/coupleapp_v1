import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/theme.dart';
import '../services/google_calendar_service.dart';
import 'ocr_review_screen.dart';

class GoogleCalendarScreen extends StatefulWidget {
  final String userId;
  final String? coupleId;
  final String? partnerId;
  final String? partnerNickname;

  const GoogleCalendarScreen({
    super.key,
    required this.userId,
    required this.coupleId,
    this.partnerId,
    this.partnerNickname,
  });

  @override
  State<GoogleCalendarScreen> createState() => _GoogleCalendarScreenState();
}

enum _ImportMode { month, year, all }

class _GoogleCalendarScreenState extends State<GoogleCalendarScreen> {
  final _service = GoogleCalendarService();

  GoogleSignInAccount? _account;
  bool _isLoading = false;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  _ImportMode _importMode = _ImportMode.month;

  @override
  void initState() {
    super.initState();
    _checkSignIn();
  }

  Future<void> _checkSignIn() async {
    final signed = await _service.isSignedIn();
    if (signed && mounted) {
      setState(() => _account = _service.currentUser);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final account = await _service.signIn();
      if (mounted) setState(() => _account = account);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _service.signOut();
    if (mounted) setState(() => _account = null);
  }

  String get _importLabel {
    switch (_importMode) {
      case _ImportMode.month:
        return '$_selectedYear년 $_selectedMonth월';
      case _ImportMode.year:
        return '$_selectedYear년';
      case _ImportMode.all:
        return '전체';
    }
  }

  Future<void> _importEvents() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> events;
      switch (_importMode) {
        case _ImportMode.month:
          events = await _service.getMonthEvents(_selectedYear, _selectedMonth);
        case _ImportMode.year:
          events = await _service.getYearEvents(_selectedYear);
        case _ImportMode.all:
          events = await _service.getAllEvents();
      }

      if (events.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_importLabel에 일정이 없습니다')),
          );
        }
        return;
      }

      if (!mounted) return;

      final saved = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => OcrReviewScreen(
            schedules: events,
            ocrYear: _selectedYear,
            ocrMonth: _selectedMonth,
            importLabel: _importLabel,
            userId: widget.userId,
            coupleId: widget.coupleId,
            isGoogleCalendar: true,
          ),
        ),
      );
      if (saved != null && saved > 0 && mounted) {
        Navigator.pop(context, saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('구글 캘린더 연동')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 계정 상태
            _buildAccountCard(),
            const SizedBox(height: 24),

            if (_account != null) ...[
              // 가져오기 범위 선택
              _buildPicker(),
              const SizedBox(height: 32),

              // 가져오기 버튼
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importEvents,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(
                    _isLoading ? '불러오는 중...' : '$_importLabel 일정 가져오기',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4285F4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    if (_account == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFF4285F4)),
            const SizedBox(height: 16),
            const Text(
              '구글 캘린더 일정을 앱으로 가져옵니다',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _signIn,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.login),
                label: const Text('Google 계정으로 로그인'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4285F4), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _account!.displayName ?? '연결됨',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _account!.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _signOut,
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가져올 범위 선택',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // 모드 선택 탭
          Row(
            children: [
              _modeChip('월 선택', _ImportMode.month),
              const SizedBox(width: 8),
              _modeChip('연도 선택', _ImportMode.year),
              const SizedBox(width: 8),
              _modeChip('전체', _ImportMode.all),
            ],
          ),
          if (_importMode != _ImportMode.all) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // 연도 드롭다운 (항상 표시)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '연도',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            isExpanded: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            items: List.generate(5, (i) {
                              final year = DateTime.now().year - 2 + i;
                              return DropdownMenuItem(
                                value: year,
                                child: Text('$year년'),
                              );
                            }),
                            onChanged: (v) => setState(() => _selectedYear = v!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 월 드롭다운 (월 선택 모드일 때만)
                if (_importMode == _ImportMode.month) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '월',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedMonth,
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              items: List.generate(12, (i) {
                                return DropdownMenuItem(
                                  value: i + 1,
                                  child: Text('${i + 1}월'),
                                );
                              }),
                              onChanged: (v) => setState(() => _selectedMonth = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(String label, _ImportMode mode) {
    final selected = _importMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _importMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4285F4)
              : const Color(0xFF4285F4).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF4285F4)
                : const Color(0xFF4285F4).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}

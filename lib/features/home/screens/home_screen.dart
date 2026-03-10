import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';
import '../services/home_service.dart';
import '../widgets/dday_widget.dart';
import '../widgets/next_date_widget.dart';
import '../widgets/today_schedule_widget.dart';
import '../../../main.dart' show TabSwitchNotification;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _homeService = HomeService();

  Map<String, dynamic> _data = {};
  bool _isLoading = true;

  String? _coupleId;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = supabase.auth.currentUser?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    _coupleId = await _homeService.getCoupleId();
    if (_coupleId == null) return;

    setState(() => _isLoading = true);

    try {
      final summary = await _homeService.getHomeSummary(_coupleId!);
      if (mounted) {
        setState(() {
          _data = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int? get _dDays => _data['d_days']?['days'] as int?;
  DateTime? get _startedAt => _data['d_days']?['started_at'] as DateTime?;
  Map<String, List<Schedule>>? get _todaySchedules =>
      _data['today_schedules'] as Map<String, List<Schedule>>?;
  Map<String, dynamic>? get _nextDate => _data['next_date'] as Map<String, dynamic>?;

  void _navigateToCalendar() {
    TabSwitchNotification(1).dispatch(context); // 캘린더 탭 (index 1)
  }

  void _onDDayTap() {
    // D-day 설정 화면 - 다이얼로그로 날짜 선택
    final currentStartedAt = _startedAt;
    if (currentStartedAt == null) return;

    showDatePicker(
      context: context,
      initialDate: currentStartedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    ).then((date) async {
      if (date != null && _coupleId != null) {
        try {
          await supabase
              .from('couples')
              .update({'started_at': date.toIso8601String().split('T')[0]})
              .eq('id', _coupleId!);
          if (mounted) {
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('D-day가 업데이트되었습니다')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('D-day 업데이트 실패: $e')),
            );
          }
        }
      }
    });
  }

  void _onNextDateTap() {
    TabSwitchNotification(1).dispatch(context); // 캘린더로 이동해서 해당 날짜 확인
  }

  void _onTodayScheduleTap() {
    TabSwitchNotification(1).dispatch(context); // 오늘 일정을 위해 캘린더 탭으로 이동
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][today.weekday - 1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coupleId == null
              ? _buildNoCoupleState()
              : _buildHomeContent(weekday),
    );
  }

  Widget _buildNoCoupleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            '커플 연결이 필요합니다',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // 커플 연결 화면으로 이동
            },
            icon: const Icon(Icons.group_add),
            label: const Text('커플 연결'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(String weekday) {
    return Column(
      children: [
        // D-day 위젯
        DDayWidget(
          days: _dDays,
          startedAt: _startedAt,
          onTap: _onDDayTap,
        ),
        const SizedBox(height: 16),
        // 다음 데이트 위젯
        if (_nextDate != null) ...[
          NextDateWidget(
            nextDateSchedule: _nextDate!['schedule'] as Schedule,
            daysUntil: _nextDate!['days_until'] as int,
            onTap: _onNextDateTap,
          ),
          const SizedBox(height: 16),
        ],
        // 오늘 일정 위젯
        TodayScheduleWidget(
          todaySchedules: _todaySchedules ?? {},
          weekday: weekday,
          onTap: _onTodayScheduleTap,
        ),
        const SizedBox(height: 16),
        // 캘린더로 이동 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _navigateToCalendar,
              icon: const Icon(Icons.calendar_today),
              label: const Text('캘린더로 이동'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surface,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: AppTheme.border, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

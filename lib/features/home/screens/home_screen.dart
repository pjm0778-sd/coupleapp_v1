import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';
import '../services/home_service.dart';
import '../widgets/dday_widget.dart';
import '../widgets/next_date_widget.dart';
import '../widgets/today_schedule_widget.dart';

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _onDDayTap() async {
    // D-day 설정 화면 - 다이얼로그로 날짜 선택
    final currentStartedAt = _startedAt ?? DateTime(2020, 1, 1);

    final date = await showDatePicker(
      context: context,
      initialDate: currentStartedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      try {
        // coupleId 다시 가져오기 (커플 연결 상태 확인)
        _coupleId = await _homeService.getCoupleId();
        if (_coupleId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('커플 연결이 필요합니다')),
            );
          }
          return;
        }

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
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
            ),
            const SizedBox(height: 16),
          ],
          // 오늘 일정 위젯
          TodayScheduleWidget(
            todaySchedules: _todaySchedules ?? {},
            weekday: weekday,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme.dart';
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
  bool _hasLoadedOnce = false;

  String? _coupleId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 다른 탭(설정 등)에서 돌아올 때 데이터 갱신
    if (_hasLoadedOnce) {
      _loadData();
    }
    _hasLoadedOnce = true;
  }

  Future<void> _loadData() async {
    _coupleId = await _homeService.getCoupleId();
    if (_coupleId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

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
  String? get _partnerNickname => _data['d_days']?['partner_nickname'] as String?;
  Map<String, List<Schedule>>? get _todaySchedules =>
      _data['today_schedules'] as Map<String, List<Schedule>>?;
  Map<String, List<Schedule>>? get _tomorrowSchedules =>
      _data['tomorrow_schedules'] as Map<String, List<Schedule>>?;
  Map<String, dynamic>? get _nextDate => _data['next_date'] as Map<String, dynamic>?;

  bool _hasSchedules(Map<String, List<Schedule>>? schedules) {
    if (schedules == null) return false;
    return (schedules['mine']?.isNotEmpty ?? false) ||
        (schedules['partner']?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final todayWeekday = weekdays[today.weekday - 1];
    final tomorrowWeekday = weekdays[tomorrow.weekday - 1];

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
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
          ? const Center(child: CircularProgressIndicator())
          : _coupleId == null
              ? _buildNoCoupleState()
              : _buildHomeContent(todayWeekday, tomorrowWeekday),
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
            style: TextStyle(fontSize: 18, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(String todayWeekday, String tomorrowWeekday) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // D+day 위젯 (화면 1/6 크기, 탭 설정 없음)
          DDayWidget(
            days: _dDays,
            partnerNickname: _partnerNickname,
          ),
          const SizedBox(height: 16),
          // 다가오는 데이트
          if (_nextDate != null) ...[
            NextDateWidget(
              nextDateSchedule: _nextDate!['schedule'] as Schedule,
              daysUntil: _nextDate!['days_until'] as int,
            ),
            const SizedBox(height: 16),
          ],
          // 오늘의 일정
          TodayScheduleWidget(
            todaySchedules: _todaySchedules ?? {},
            weekday: todayWeekday,
            title: '오늘의 일정',
          ),
          // 내일의 일정 (일정이 있을 때만 표시)
          if (_hasSchedules(_tomorrowSchedules)) ...[
            const SizedBox(height: 16),
            TodayScheduleWidget(
              todaySchedules: _tomorrowSchedules ?? {},
              weekday: tomorrowWeekday,
              title: '내일의 일정',
            ),
          ],
        ],
      ),
    );
  }
}

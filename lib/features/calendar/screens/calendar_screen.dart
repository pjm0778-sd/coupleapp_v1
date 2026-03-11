import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_add_dialog.dart';
import '../widgets/schedule_detail.dart';
import '../widgets/calendar_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = ScheduleService();
  ScheduleFilter _filter = ScheduleFilter.both;
  DateTime _focusedMonth = DateTime.now();
  Map<DateTime, List<Schedule>> _events = {};
  bool _isLoading = true;

  String? _coupleId;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = supabase.auth.currentUser?.id;
    _init();
  }

  Future<void> _init() async {
    _coupleId = await _service.getCoupleId();
    await _loadSchedules(_focusedMonth);
  }

  Future<void> _loadSchedules(DateTime month) async {
    if (_coupleId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final list = await _service.getMonthSchedules(_coupleId!, month, filter: _filter);
      final map = <DateTime, List<Schedule>>{};
      for (final s in list) {
        final key = DateTime(s.date.year, s.date.month, s.date.day);
        map.putIfAbsent(key, () => []).add(s);
      }
      if (mounted) setState(() { _events = map; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(ScheduleFilter filter) {
    setState(() => _filter = filter);
    _loadSchedules(_focusedMonth);
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '근무':
        return const Color(0xFF4CAF50); // 녹색
      case '약속':
        return const Color(0xFF2196F3); // 파랑
      case '여행':
        return const Color(0xFFFF9800); // 주황
      case '데이트':
        return const Color(0xFFE91E63); // 핑크
      case '휴무':
        return const Color(0xFFBDBDBD); // 회색
      default:
        return AppTheme.primary;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '근무':
        return Icons.work_outline;
      case '약속':
        return Icons.handshake_outlined;
      case '여행':
        return Icons.flight_takeoff_outlined;
      case '데이트':
        return Icons.favorite_outline;
      case '휴무':
        return Icons.beach_access_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
    if (start == null || end == null) return '';
    return '${_formatTime(start)} ~ ${_formatTime(end)}';
  }

  void _onScheduleTap(Schedule schedule) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleDetailScreen(schedule: schedule),
      ),
    );
    // 일정이 삭제되었거나 수정되었으면 새로고침
    if (result == true && mounted) {
      _loadSchedules(_focusedMonth);
    }
  }

  void _showAddDialog(DateTime? date) async {
    final result = await showDialog<Schedule>(
      context: context,
      builder: (context) => ScheduleAddDialog(date: date),
    );
    // 일정이 추가되었으면 새로고침
    if (result != null && mounted) {
      _loadSchedules(_focusedMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_focusedMonth.year}년 ${_focusedMonth.month}월'),
        actions: [
          // '+' 버튼
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(null),
            tooltip: '일정 추가',
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터/토글
          _buildFilterBar(),
          const Divider(height: 1),
          // 캘린더 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCalendarList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.surface,
      child: Row(
        children: [
          _FilterChip(
            label: '나만',
            isSelected: _filter == ScheduleFilter.mine,
            onTap: () => _onFilterChanged(ScheduleFilter.mine),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '파트너만',
            isSelected: _filter == ScheduleFilter.partner,
            onTap: () => _onFilterChanged(ScheduleFilter.partner),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '둘 다',
            isSelected: _filter == ScheduleFilter.both,
            onTap: () => _onFilterChanged(ScheduleFilter.both),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarList() {
    final today = DateTime.now();
    final monthDays = _getDaysInMonth(_focusedMonth);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: monthDays.length,
      itemBuilder: (context, index) {
        final date = monthDays[index];
        final schedules = _events[DateTime(date.year, date.month, date.day)] ?? [];
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final weekday = ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];

        return GestureDetector(
          onLongPress: () => _showAddDialog(date),
          child: CalendarCard(
            date: date,
            weekday: weekday,
            isToday: isToday,
            schedules: schedules,
            onScheduleTap: _onScheduleTap,
            getCategoryColor: _getCategoryColor,
            getCategoryIcon: _getCategoryIcon,
            formatTime: _formatTime,
            formatTimeRange: _formatTimeRange,
          ),
        );
      },
    );
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];

    for (var date = firstDay;
        date.isBefore(lastDay);
        date = date.add(const Duration(days: 1))) {
      days.add(date);
    }
    return days;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

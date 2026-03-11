import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
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
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Schedule>> _events = {};
  bool _isLoading = true;
  bool _showCalendarGrid = true; // 달력 형식 기본

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

  List<Schedule> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '근무': return const Color(0xFF4CAF50);
      case '약속': return const Color(0xFF2196F3);
      case '여행': return const Color(0xFFFF9800);
      case '데이트': return const Color(0xFFE91E63);
      case '휴무': return const Color(0xFFBDBDBD);
      default: return AppTheme.primary;
    }
  }

  Color _getScheduleColor(Schedule s) {
    if (s.colorHex != null && s.colorHex!.isNotEmpty) {
      try {
        return Color(int.parse('FF${s.colorHex!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }
    return _getCategoryColor(s.category);
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '근무': return Icons.work_outline;
      case '약속': return Icons.handshake_outlined;
      case '여행': return Icons.flight_takeoff_outlined;
      case '데이트': return Icons.favorite_outline;
      case '휴무': return Icons.beach_access_outlined;
      default: return Icons.event_outlined;
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
    if (result == true && mounted) {
      _loadSchedules(_focusedMonth);
    }
  }

  void _showAddDialog(DateTime? date) async {
    final result = await showDialog<Schedule>(
      context: context,
      builder: (context) => ScheduleAddDialog(date: date ?? _selectedDay),
    );
    if (result != null && mounted) {
      try {
        if (_coupleId == null || _myUserId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('커플 연결이 필요합니다')),
          );
          return;
        }
        final scheduleToSave = result.copyWith(
          userId: _myUserId,
          coupleId: _coupleId,
        );
        await _service.addSchedule(scheduleToSave);
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 추가되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정 저장 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_focusedMonth.year}년 ${_focusedMonth.month}월'),
        actions: [
          IconButton(
            icon: Icon(_showCalendarGrid ? Icons.view_list : Icons.calendar_month),
            onPressed: () => setState(() => _showCalendarGrid = !_showCalendarGrid),
            tooltip: _showCalendarGrid ? '목록 보기' : '달력 보기',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(null),
            tooltip: '일정 추가',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          if (_showCalendarGrid) _buildTableCalendar(),
          if (_showCalendarGrid) const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _showCalendarGrid
                    ? _buildSelectedDaySchedules()
                    : _buildCalendarList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCalendar() {
    return TableCalendar<Schedule>(
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      focusedDay: _focusedMonth,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedMonth = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedMonth = focusedDay;
        _loadSchedules(focusedDay);
      },
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        outsideDaysVisible: false,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders<Schedule>(
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: events.take(3).map((s) {
              final color = _getScheduleColor(s);
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildSelectedDaySchedules() {
    final schedules = _getEventsForDay(_selectedDay);
    final dateStr = '${_selectedDay.month}월 ${_selectedDay.day}일 (${['월','화','수','목','금','토','일'][_selectedDay.weekday - 1]})';

    if (schedules.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '일정이 없어요',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '$dateStr · ${schedules.length}건',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: schedules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = schedules[index];
              final color = _getScheduleColor(s);
              return GestureDetector(
                onTap: () => _onScheduleTap(s),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        child: Icon(_getCategoryIcon(s.category), color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title ?? s.workType ?? '일정',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (s.startTime != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formatTimeRange(s.startTime, s.endTime),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // 내 일정 vs 파트너 일정 구분
                      if (_myUserId != null)
                        Icon(
                          s.userId == _myUserId ? Icons.person : Icons.favorite,
                          size: 16,
                          color: s.userId == _myUserId ? AppTheme.textSecondary : AppTheme.accent,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
        !date.isAfter(lastDay);
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

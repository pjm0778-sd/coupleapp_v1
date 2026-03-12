import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/holiday_service.dart';
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
  final _holidayService = HolidayService();

  ScheduleFilter _filter = ScheduleFilter.both;
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Schedule>> _events = {};
  Map<DateTime, List<Holiday>> _holidays = {};
  bool _isLoading = true;
  bool _showCalendarGrid = true;

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
    _loadHolidays(_focusedMonth);
    await _loadSchedules(_focusedMonth);
  }

  void _loadHolidays(DateTime month) {
    final holidays = _holidayService.getMonthHolidays(month);
    if (mounted) setState(() => _holidays = holidays);
  }

  Future<void> _loadSchedules(DateTime month) async {
    if (_coupleId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final list = await _service.getMonthSchedules(_coupleId!, month,
          filter: _filter);
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

  List<Holiday> _getHolidaysForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _holidays[key] ?? [];
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
        return Color(
            int.parse('FF${s.colorHex!.replaceAll('#', '')}', radix: 16));
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

  Future<void> _deleteMyMonthSchedules() async {
    if (_myUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('월별 일정 전체 삭제'),
        content: Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월의 본인 일정을 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final count = await _service.deleteMyMonthSchedules(_focusedMonth);
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$count개의 일정이 삭제되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정 삭제 실패: $e')),
          );
        }
      }
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
        final scheduleToSave =
            result.copyWith(userId: _myUserId, coupleId: _coupleId);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(null),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
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
        // 공휴일/기념일 정보 스낵바
        final holidays = _getHolidaysForDay(selectedDay);
        if (holidays.isNotEmpty) {
          final names = holidays.map((h) => '${h.emoji} ${h.name}').join(' · ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(names),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      onPageChanged: (focusedDay) {
        _focusedMonth = focusedDay;
        _loadHolidays(focusedDay);
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
        // 주말 색상
        weekendTextStyle: const TextStyle(color: Color(0xFFE53935)),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders<Schedule>(
        // 날짜 셀 커스텀 빌더 (공휴일 이름 + 일정 마커)
        defaultBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, isSelected: false, isToday: false);
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, isSelected: true, isToday: false);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildDayCell(day, isSelected: false, isToday: true);
        },
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return const SizedBox.shrink();
          final holidays = _getHolidaysForDay(date);
          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 일정 마커
                ...events.take(3).map((s) {
                  final color = _getScheduleColor(s);
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 0.8),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  );
                }),
                // 공휴일/기념일 마커
                if (holidays.isNotEmpty)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 0.8),
                    decoration: BoxDecoration(
                      color: holidays.first.color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(DateTime day,
      {required bool isSelected, required bool isToday}) {
    final holidays = _getHolidaysForDay(day);
    final isPublicHoliday =
        holidays.any((h) => h.type == HolidayType.publicHoliday);
    final isSunday = day.weekday == DateTime.sunday;
    final isSaturday = day.weekday == DateTime.saturday;

    Color textColor = AppTheme.textPrimary;
    if (isPublicHoliday || isSunday) textColor = const Color(0xFFE53935);
    if (isSaturday) textColor = const Color(0xFF1565C0);
    if (isSelected) textColor = Colors.white;

    BoxDecoration decoration;
    if (isSelected) {
      decoration = const BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        color: AppTheme.primary.withOpacity(0.2),
        shape: BoxShape.circle,
      );
    } else {
      decoration = const BoxDecoration();
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: decoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          // 공휴일 이름 (짧게)
          if (holidays.isNotEmpty)
            Text(
              holidays.first.name.length > 3
                  ? holidays.first.name.substring(0, 3)
                  : holidays.first.name,
              style: TextStyle(
                fontSize: 7,
                color: isSelected ? Colors.white70 : holidays.first.color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.clip,
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDaySchedules() {
    final schedules = _getEventsForDay(_selectedDay);
    final holidays = _getHolidaysForDay(_selectedDay);
    final dateStr =
        '${_selectedDay.month}월 ${_selectedDay.day}일 (${['월', '화', '수', '목', '금', '토', '일'][_selectedDay.weekday - 1]})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 날짜 헤더 + 공휴일 배너
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dateStr · ${schedules.length}건',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (holidays.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: holidays.map((h) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: h.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: h.color.withOpacity(0.4)),
                      ),
                      child: Text(
                        '${h.emoji} ${h.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: h.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: schedules.isEmpty
              ? Center(
                  child: Text(
                    holidays.isNotEmpty
                        ? '일정이 없어요 🎉'
                        : '일정이 없어요',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ),
                )
              : ListView.separated(
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
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                              child: Icon(_getCategoryIcon(s.category),
                                  color: Colors.white, size: 18),
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
                            if (_myUserId != null)
                              Icon(
                                s.userId == _myUserId
                                    ? Icons.person
                                    : Icons.favorite,
                                size: 16,
                                color: s.userId == _myUserId
                                    ? AppTheme.textSecondary
                                    : AppTheme.accent,
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
          const Spacer(),
          // 뷰 전환 버튼
          GestureDetector(
            onTap: () => setState(() => _showCalendarGrid = !_showCalendarGrid),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(
                _showCalendarGrid
                    ? Icons.view_list_outlined
                    : Icons.calendar_month_outlined,
                size: 18,
                color: AppTheme.textPrimary,
              ),
            ),
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
        final schedules =
            _events[DateTime(date.year, date.month, date.day)] ?? [];
        final holidays =
            _holidays[DateTime(date.year, date.month, date.day)] ?? [];
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
            holidays: holidays,
            onScheduleTap: _onScheduleTap,
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

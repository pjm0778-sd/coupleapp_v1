import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/models/shift_type.dart';
import '../../core/models/holiday.dart';
import '../services/holiday_service.dart';
import '../services/user_settings_service.dart';
import '../../shared/models/schedule.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  ShiftType? _shiftType;
  String? _defaultShift;
  Map<DateTime, Schedule> _schedules = {};
  final Map<DateTime, Schedule> _partnerSchedules = {};
  bool _isLoading = true;

  final HolidayService _holidayService = HolidayService();
  final UserSettingsService _settingsService = UserSettingsService();

  // 일반 평일/직장인 근무형태들
  final List<String> _regularShifts = ['주간근무', '휴무', '당직', '휴가'];
  int _currentShiftIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 사용자 설정 로드
    final settings = await _settingsService.getUserSettings(userId);
    _shiftType = settings?.shiftType ?? ShiftType.regularOffice;
    _defaultShift = settings?.defaultShift ?? '주간근무';

    // 스케줄 로드
    await _loadSchedules(userId);
  }

  Future<void> _loadSchedules(String userId) async {
    final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    final data = await supabase
        .from('schedules')
        .select()
        .eq('user_id', userId)
        .gte('date', start.toIso8601String().split('T')[0])
        .lt('date', end.toIso8601String().split('T')[0]);

    if (!mounted) return;

    setState(() {
      _schedules = {
        for (final item in data)
          DateTime.parse(item['date'] as String): Schedule.fromMap(item)
      };
      _partnerSchedules = {
        for (final item in data)
          if (item['user_id'] != userId)
            DateTime.parse(item['date'] as String): Schedule.fromMap(item)
      };
      _isLoading = false;
    });
  }

  bool _isHoliday(DateTime date) {
    return _holidayService.isHoliday(date);
  }

  Color? _getDayColor(DateTime date) {
    // 공휴일
    if (_isHoliday(date)) {
      return const Color(0xFF4CAF50); // 녹색
    }

    // 주말 (토요일=6, 일요일=7)
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return const Color(0xFF9E9E9E); // 회색
    }

    // 사용자 스케줄
    final schedule = _schedules[date];
    if (schedule != null) return null;

    return schedule!.color;
  }

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    // 일반 평일/직장인 경우: 근무형태 순환
    if (_shiftType == ShiftType.regularOffice && _defaultShift != null) {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final nextShiftIndex = (_currentShiftIndex + 1) % _regularShifts.length;
      final nextShift = _regularShifts[nextShiftIndex];

      setState(() => _currentShiftIndex = nextShiftIndex);

      // 스케줄 생성 (예시)
      await _showShiftDialog(selectedDay, nextShift);
    }
  }

  Future<void> _showShiftDialog(DateTime date, String shift) async {
    if (!mounted) return;

    final color = _getShiftColor(shift);

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${date.month}월 ${date.day}일'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    shift[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              title: Text(_getShiftLabel(shift)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createSchedule(date, shift, color);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSchedule(DateTime date, String shift, Color color) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final coupleId = await _getCoupleId(userId);
    if (coupleId == null) return;

    try {
      await supabase.from('schedules').insert({
        'user_id': userId,
        'couple_id': coupleId,
        'date': date.toIso8601String().split('T')[0],
        'shift': shift,
        'color_hex': '#${color.value.toRadixString(16).padLeft(6, '0')}',
      });

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스케줄이 등록되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<String?> _getCoupleId(String userId) async {
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .maybeSingle();

    return profile?['couple_id'] as String?;
  }

  String _getShiftLabel(String shift) {
    switch (shift) {
      case '주간근무':
        return '주간 근무';
      case '휴무':
        return '휴무';
      case '당직':
        return '당직';
      case '휴가':
        return '휴가';
      default:
        return shift;
    }
  }

  Color _getShiftColor(String shift) {
    switch (shift) {
      case '주간근무':
        return const Color(0xFF4CAF50); // 녹색
      case '휴무':
        return const Color(0xFF90CAF9); // 파란색
      case '당직':
        return const Color(0xFFFF9800); // 주황색
      case '휴가':
        return const Color(0xFFE91E63); // 오렌지색
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_focusedDay.year}년 ${_focusedDay.month}월'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/shift_type');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 범례
          _buildLegend(),
          // 달력
          Expanded(
            child: TableCalendar(
              firstDay: DateTime.monday,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: (date) {
                  final hasSchedule = _schedules[date] != null;
                  final hasPartnerSchedule = _partnerSchedules[date] != null;

                  return BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasSchedule
                        ? Colors.white
                        : hasPartnerSchedule
                            ? AppTheme.primary
                            : Colors.transparent,
                    border: hasSchedule
                        ? Border.all(color: _schedules[date]!.color)
                        : hasPartnerSchedule
                            ? Border.all(color: _partnerSchedules[date]!.color)
                            : null,
                  );
                },
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final isHoliday = _isHoliday(day);
                  final dayColor = _getDayColor(day);

                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isHoliday
                          ? const Color(0xFF4CAF50).withOpacity(0.3)
                          : Colors.transparent,
                      border: Border.all(color: AppTheme.border),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isHoliday
                              ? const Color(0xFF4CAF50)
                              : (dayColor != null)
                                  ? AppTheme.textPrimary
                                  : dayColor,
                          fontWeight: dayColor != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
              onDaySelected: _onDaySelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        children: [
          _buildLegendItem('공휴일', const Color(0xFF4CAF50)),
          _buildLegendItem('주말', const Color(0xFF9E9E9E)),
          _buildLegendItem('나의 스케줄', AppTheme.border),
          _buildLegendItem('파트너 스케줄', AppTheme.primary),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

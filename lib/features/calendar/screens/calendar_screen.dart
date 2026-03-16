import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  DateTime? _startedAt;
  String? _partnerNickname;

  String? _coupleId;
  String? _myUserId;
  String? _partnerId;
  RealtimeChannel? _schedulesChannel;

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentUser?.id;
    _init();
  }

  Future<void> _init() async {
    _coupleId = await _service.getCoupleId();
    if (_coupleId != null) {
      final coupleData = await supabase
          .from('couples')
          .select('started_at, user1_id, user2_id')
          .eq('id', _coupleId!)
          .maybeSingle();

      if (coupleData != null) {
        if (coupleData['started_at'] != null) {
          _startedAt = DateTime.parse(coupleData['started_at'] as String);
        }

        // 파트너 닉네임 가져오기
        final partnerId = coupleData['user1_id'] == _myUserId
            ? coupleData['user2_id']
            : coupleData['user1_id'];

        if (partnerId != null) {
          final partnerData = await supabase
              .from('profiles')
              .select('nickname')
              .eq('id', partnerId)
              .maybeSingle();
          if (mounted) {
            setState(() {
              _partnerNickname = partnerData?['nickname'];
              _partnerId = partnerId?.toString();
            });
          }
        }
      }
      _setupRealtime();
    }
    _loadHolidays(_focusedMonth);
    await _loadSchedules(_focusedMonth);
  }

  void _setupRealtime() {
    if (_coupleId == null) return;

    _schedulesChannel ??=
        Supabase.instance.client
            .channel('public:schedules_calendar')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'schedules',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'couple_id',
                value: _coupleId!,
              ),
              callback: (payload) {
                if (mounted) _loadSchedules(_focusedMonth);
              },
            )
          ..subscribe();
  }

  @override
  void dispose() {
    _schedulesChannel?.unsubscribe();
    super.dispose();
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
      final list = await _service.getMonthSchedules(
        _coupleId!,
        month,
        filter: _filter,
      );

      // 기념일 계산 (100일, 200일, 1주년 등)
      final anniversaries = _generateAnniversaries(month);
      list.addAll(anniversaries);

      final map = <DateTime, List<Schedule>>{};
      for (final s in list) {
        final start = s.startDate ?? s.date;
        final end = s.endDate ?? start;
        var current = DateTime(start.year, start.month, start.day);
        final endDay = DateTime(end.year, end.month, end.day);
        while (!current.isAfter(endDay)) {
          map.putIfAbsent(current, () => []).add(s);
          current = current.add(const Duration(days: 1));
        }
      }
      if (mounted) {
        setState(() {
          _events = map;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(ScheduleFilter filter) {
    setState(() => _filter = filter);
    _loadSchedules(_focusedMonth);
  }

  List<Schedule> _generateAnniversaries(DateTime month) {
    final results = <Schedule>[];
    if (_startedAt == null) return results;

    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    // 100일 단위 기념일 (1000일까지 확인)
    for (int i = 1; i <= 10; i++) {
      final targetDate = _startedAt!.add(Duration(days: (i * 100) - 1));
      if (targetDate.isAfter(start.subtract(const Duration(days: 1))) &&
          targetDate.isBefore(end.add(const Duration(days: 1)))) {
        results.add(
          Schedule(
            id: 'anniv_100_$i',
            userId: 'system',
            coupleId: _coupleId,
            date: targetDate,
            title: '${i * 100}일',
            category: '기념일',
            colorHex: '#FF4081',
            isAnniversary: true,
          ),
        );
      }
    }

    // 1년 단위 기념일 (10주년까지 확인)
    for (int i = 1; i <= 10; i++) {
      final targetDate = DateTime(
        _startedAt!.year + i,
        _startedAt!.month,
        _startedAt!.day,
      );
      if (targetDate.year == month.year && targetDate.month == month.month) {
        results.add(
          Schedule(
            id: 'anniv_yr_$i',
            userId: 'system',
            coupleId: _coupleId,
            date: targetDate,
            title: '$i주년',
            category: '기념일',
            colorHex: '#FF4081',
            isAnniversary: true,
          ),
        );
      }
    }

    return results;
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
      case '근무':
        return const Color(0xFF4CAF50);
      case '약속':
        return const Color(0xFF2196F3);
      case '여행':
        return const Color(0xFFFF9800);
      case '데이트':
        return const Color(0xFFE91E63);
      case '휴무':
        return const Color(0xFFBDBDBD);
      case '기념일':
        return const Color(0xFFFF4081);
      default:
        return AppTheme.primary;
    }
  }

  Color _getScheduleColor(Schedule s) {
    if (s.colorHex != null && s.colorHex!.isNotEmpty) {
      try {
        return Color(
          int.parse('FF${s.colorHex!.replaceAll('#', '')}', radix: 16),
        );
      } catch (_) {}
    }
    return _getCategoryColor(s.category);
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
      case '기념일':
        return Icons.cake_outlined;
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
    if (schedule.isAnniversary) return; // 기념일은 클릭 불가
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

  Future<void> _editScheduleItem(Schedule schedule) async {
    final result = await showDialog<Schedule>(
      context: context,
      builder: (context) => ScheduleAddDialog(existingSchedule: schedule),
    );
    if (result != null && mounted) {
      try {
        await _service.updateSchedule(schedule.id, result.toMap());
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('일정이 수정되었습니다')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('일정 수정 실패: $e')));
        }
      }
    }
  }

  Future<void> _deleteScheduleItem(Schedule schedule) async {
    try {
      await _service.deleteSchedule(schedule.id);
      await _loadSchedules(_focusedMonth);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('일정 삭제 실패')));
      }
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
            SnackBar(
              content: Text(
                count > 0 ? '$count개의 일정을 삭제했습니다.' : '삭제할 일정이 없습니다.',
              ),
            ),
          );
        }
      } catch (e) {
        // 이미 삭제가 성공했더라도 select() 결과 처리 등에서 에러가 날 수 있으므로
        // 데이터를 다시 로드하여 실제 삭제 여부를 확인합니다.
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('일정이 삭제되었습니다.')));
        }
      }
    }
  }

  Future<void> _deleteOcrMonthSchedules() async {
    if (_myUserId == null) return;

    // 누구의 OCR 일정을 삭제할지 선택
    String targetUserId = _myUserId!;
    String targetLabel = '내';
    if (_partnerId != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('누구의 OCR 일정을 삭제할까요?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('나의 OCR 일정'),
                onTap: () => Navigator.pop(context, 'me'),
              ),
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                title: Text('${_partnerNickname ?? '파트너'}의 OCR 일정'),
                onTap: () => Navigator.pop(context, 'partner'),
              ),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'partner') {
        targetUserId = _partnerId!;
        targetLabel = '${_partnerNickname ?? '파트너'}의';
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OCR 일정 삭제'),
        content: Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월의 $targetLabel OCR 자동등록 일정을 모두 삭제하시겠습니까?\n구글 캘린더 연동 일정은 삭제되지 않습니다.\n이 작업은 되돌릴 수 없습니다.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final int count;
        if (targetUserId == _myUserId) {
          count = await _service.deleteMyOcrMonthSchedules(
            _focusedMonth,
            _coupleId!,
          );
        } else {
          count = await _service.deletePartnerOcrMonthSchedules(
            _focusedMonth,
            targetUserId,
            _coupleId!,
          );
        }
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count > 0
                    ? 'OCR 일정 $count개를 삭제했습니다.'
                    : '삭제할 OCR 일정이 없습니다.',
              ),
            ),
          );
        }
      } catch (e) {
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('OCR 일정이 삭제되었습니다.')));
        }
      }
    }
  }

  Future<void> _deleteGoogleCalendarMonthSchedules() async {
    if (_myUserId == null) return;

    // 누구의 구글 캘린더 일정을 삭제할지 선택
    String targetUserId = _myUserId!;
    String targetLabel = '내';
    if (_partnerId != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('누구의 구글 캘린더 일정을 삭제할까요?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('나의 구글 캘린더 일정'),
                onTap: () => Navigator.pop(context, 'me'),
              ),
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                title: Text('${_partnerNickname ?? '파트너'}의 구글 캘린더 일정'),
                onTap: () => Navigator.pop(context, 'partner'),
              ),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'partner') {
        targetUserId = _partnerId!;
        targetLabel = '${_partnerNickname ?? '파트너'}의';
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구글 캘린더 일정 삭제'),
        content: Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월의 $targetLabel 구글 캘린더 연동 일정을 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final int count;
        if (targetUserId == _myUserId) {
          count = await _service.deleteMyGoogleCalendarMonthSchedules(
            _focusedMonth,
            _coupleId!,
          );
        } else {
          count = await _service.deletePartnerGoogleCalendarMonthSchedules(
            _focusedMonth,
            targetUserId,
            _coupleId!,
          );
        }
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count > 0
                    ? '구글 캘린더 일정 $count개를 삭제했습니다.'
                    : '삭제할 구글 캘린더 일정이 없습니다.',
              ),
            ),
          );
        }
      } catch (e) {
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('구글 캘린더 일정이 삭제되었습니다.')),
          );
        }
      }
    }
  }

  void _showAddDialog(DateTime? date) async {
    if (_coupleId == null || _myUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('커플 연결이 필요합니다.')));
      return;
    }

    // 필터에 따라 대상 유저 자동 결정
    // mine → 나, partner → 파트너, both → 선택 다이얼로그
    String targetUserId = _myUserId!;
    if (_filter == ScheduleFilter.partner && _partnerId != null) {
      targetUserId = _partnerId!;
    } else if (_filter == ScheduleFilter.both && _partnerId != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('누구의 일정인가요?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
      if (choice == null || !mounted) return;
      targetUserId = choice == 'partner' ? _partnerId! : _myUserId!;
    }

    final result = await showDialog<Schedule>(
      context: context,
      builder: (context) => ScheduleAddDialog(date: date ?? _selectedDay),
    );
    if (result != null && mounted) {
      try {
        final scheduleToSave = result.copyWith(
          userId: targetUserId,
          coupleId: _coupleId,
        );
        await _service.addSchedule(scheduleToSave);
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('일정을 추가했습니다.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('일정 추가 실패: $e')));
        }
      }
    }
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('연도 선택'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              selectedDate: _focusedMonth,
              onChanged: (DateTime dateTime) {
                Navigator.pop(context);
                setState(() {
                  _focusedMonth = DateTime(
                    dateTime.year,
                    _focusedMonth.month,
                    1,
                  );
                });
                _loadHolidays(_focusedMonth);
                _loadSchedules(_focusedMonth);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showYearPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: Color(0xFF4285F4),
            ),
            tooltip: '이달의 구글 캘린더 연동 일정 삭제',
            onPressed: _deleteGoogleCalendarMonthSchedules,
          ),
          IconButton(
            icon: const Icon(
              Icons.document_scanner_outlined,
              color: Colors.orangeAccent,
            ),
            tooltip: '이달의 OCR 자동등록 일정 삭제',
            onPressed: _deleteOcrMonthSchedules,
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.redAccent,
            ),
            tooltip: '이달의 내 일정 전체 삭제',
            onPressed: _deleteMyMonthSchedules,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          if (_filter == ScheduleFilter.both) _buildLegend(),
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
      locale: 'ko_KR',
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
                borderRadius: BorderRadius.circular(10),
              ),
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
        // 날짜 셀 커스텀 빌더
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

          // 나 / 파트너 / 기념일 분류
          final mySchedules = events
              .where((s) => !s.isAnniversary && s.userId == _myUserId)
              .toList();
          final partnerSchedules = events
              .where((s) => !s.isAnniversary && s.userId != _myUserId && s.userId != 'system')
              .toList();
          final anniversaries = events.where((s) => s.isAnniversary).toList();
          final holidays = _getHolidaysForDay(date);

          // 각 일정의 실제 지정 색상으로 도트 표시
          // 행 위치로 소유자 구분: 위 = 나, 아래 = 파트너
          Widget dotRow(List<Schedule> schedules) => Row(
                mainAxisSize: MainAxisSize.min,
                children: schedules
                    .take(3)
                    .map(
                      (s) => Container(
                        width: 4.5,
                        height: 4.5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.8),
                        decoration: BoxDecoration(
                          color: _getScheduleColor(s),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                    .toList(),
              );

          return Positioned(
            bottom: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 내 일정 도트 (실제 지정 색)
                if (mySchedules.isNotEmpty) dotRow(mySchedules),
                // 파트너 일정 도트 (실제 지정 색)
                if (partnerSchedules.isNotEmpty) dotRow(partnerSchedules),
                // 기념일 / 공휴일 도트
                if (anniversaries.isNotEmpty || holidays.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (anniversaries.isNotEmpty)
                        Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 0.8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF4081),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (holidays.isNotEmpty)
                        Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 0.8),
                          decoration: BoxDecoration(
                            color: holidays.first.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day, {
    required bool isSelected,
    required bool isToday,
  }) {
    final holidays = _getHolidaysForDay(day);
    final isPublicHoliday = holidays.any(
      (h) => h.type == HolidayType.publicHoliday,
    );
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
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: h.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: h.color.withOpacity(0.4)),
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
                    holidays.isNotEmpty ? '일정이 없어요 🥲' : '일정이 없어요',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: schedules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = schedules[index];
                    final color = _getScheduleColor(s);
                    final isMine = _myUserId != null && s.userId == _myUserId;

                    Widget card = GestureDetector(
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
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(s.category),
                                color: Colors.white,
                                size: 18,
                              ),
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
                                  if (s.startDate != null &&
                                      s.endDate != null &&
                                      s.endDate!.isAfter(s.startDate!)) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${s.startDate!.month}/${s.startDate!.day} ~ ${s.endDate!.month}/${s.endDate!.day}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ] else if (s.startTime != null) ...[
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

                    if (s.isAnniversary) return card;

                    return Dismissible(
                      key: Key('schedule_${s.id}_$index'),
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await _editScheduleItem(s);
                          return false;
                        } else {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('일정 삭제'),
                              content: const Text('이 일정을 삭제하시겠습니까?'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                          return ok == true;
                        }
                      },
                      onDismissed: (direction) {
                        if (direction == DismissDirection.endToStart) {
                          _deleteScheduleItem(s);
                        }
                      },
                      child: card,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppTheme.surface,
      child: Row(
        children: [
          // 나: 위 줄 도트 + 파트너: 아래 줄 도트 시각화
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendDot(color: const Color(0xFF5C85D6)),
              const SizedBox(height: 2),
              _LegendDot(color: const Color(0xFFE8A598)),
            ],
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('나 (위 줄)', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Text(
                '${_partnerNickname ?? '파트너'} (아래 줄)',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _LegendDot(color: const Color(0xFFFF4081)),
          const SizedBox(width: 4),
          const Text('기념일', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
            label: '나의 일정',
            isSelected: _filter == ScheduleFilter.mine,
            onTap: () => _onFilterChanged(ScheduleFilter.mine),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '${_partnerNickname ?? '파트너'}의 일정',
            isSelected: _filter == ScheduleFilter.partner,
            onTap: () => _onFilterChanged(ScheduleFilter.partner),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '우리의 일정',
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
        final isToday =
            date.year == today.year &&
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
    for (
      var date = firstDay;
      !date.isAfter(lastDay);
      date = date.add(const Duration(days: 1))
    ) {
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

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

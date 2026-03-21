import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/holiday_service.dart';
import '../../../shared/models/schedule.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_add_sheet.dart';
import '../widgets/day_detail_sheet.dart';
import 'date_map_screen.dart';
import '../../../features/schedule/screens/auto_registration_screen.dart';

class CalendarScreen extends StatefulWidget {
  final DateTime? initialDate;

  const CalendarScreen({super.key, this.initialDate});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = ScheduleService();
  final _holidayService = HolidayService();

  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  Map<DateTime, List<Schedule>> _events = {};
  Map<DateTime, List<Holiday>> _holidays = {};
  bool _isLoading = true;
  DateTime? _startedAt;
  String? _partnerNickname;

  String? _coupleId;
  String? _myUserId;
  String? _partnerId;
  RealtimeChannel? _schedulesChannel;
  bool _partnerGrayMode = false;

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentUser?.id;
    final base = widget.initialDate ?? DateTime.now();
    _selectedDay = DateTime(base.year, base.month, base.day);
    _focusedMonth = DateTime(base.year, base.month, base.day);
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

    // 홈화면에서 특정 날짜로 진입한 경우 자동으로 상세 시트 오픈
    if (widget.initialDate != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDayDetail(_selectedDay);
      });
    }
  }

  void _openDayDetail(DateTime date) {
    final events = _getEventsForDay(date);
    final holidays = _getHolidaysForDay(date);
    DayDetailSheet.show(
      context,
      date: date,
      schedules: _service.sortByOwner(events, _myUserId ?? ''),
      holidays: holidays,
      myUserId: _myUserId ?? '',
      partnerNickname: _partnerNickname,
      getColor: _getScheduleColor,
      onEdit: _editScheduleItem,
      onDelete: _deleteScheduleItem,
      onAddTap: () => _showAddSheet(date),
    );
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
      final list = await _service.getMonthSchedules(_coupleId!, month);

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
      // 각 날짜별 ownerType 순 정렬
      for (final key in map.keys) {
        map[key] = _service.sortByOwner(map[key]!, _myUserId ?? '');
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
            colorHex: '#C9A84C',
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
            colorHex: '#C9A84C',
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
        return AppTheme.accent;
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

  // 이벤트 바 탭은 날짜 선택만 처리 (세부 이동 제거)
  void _onScheduleTap(Schedule schedule) {}

  Future<void> _editScheduleItem(Schedule schedule) async {
    if (_coupleId == null || _myUserId == null) return;
    final result = await ScheduleAddSheet.show(
      context,
      initialDate: schedule.date,
      myUserId: _myUserId!,
      coupleId: _coupleId!,
      partnerId: _partnerId,
      partnerNickname: _partnerNickname,
      existingSchedule: schedule,
    );
    if (result != null && mounted) {
      try {
        await _service.updateSchedule(schedule.id, result.toMap());
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정이 수정되었습니다')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정 수정 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteScheduleItem(Schedule schedule) async {
    try {
      await _service.deleteSchedule(schedule.id);
      await _loadSchedules(_focusedMonth);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정 삭제 실패')),
        );
      }
    }
  }

  Future<void> _deleteMyMonthSchedules() async {
    if (_myUserId == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${_focusedMonth.year}년 ${_focusedMonth.month}월 일정 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              title: const Text('전체 삭제'),
              subtitle: const Text('이달 내 모든 내 일정 삭제'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => Navigator.pop(context, 'all'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.title_outlined, color: Colors.orange),
              title: const Text('제목으로 삭제'),
              subtitle: const Text('특정 제목의 일정만 삭제'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => Navigator.pop(context, 'title'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'all') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('전체 삭제 확인'),
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
      if (confirmed != true) return;
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
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다.')),
          );
        }
      }
    } else if (choice == 'title') {
      final controller = TextEditingController();
      final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('제목으로 삭제'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '삭제할 일정 제목',
              border: OutlineInputBorder(),
              hintText: '예: 근무, 출근',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (title == null || title.isEmpty) return;
      try {
        final count = await _service.deleteMyMonthSchedulesByTitle(
          _focusedMonth,
          title,
        );
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count > 0
                    ? '"$title" 일정 $count개를 삭제했습니다.'
                    : '삭제할 일정이 없습니다.',
              ),
            ),
          );
        }
      } catch (e) {
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  Future<void> _deleteOcrMonthSchedules() async {
    if (_myUserId == null) return;

    String targetUserId = _myUserId!;
    String targetLabel = '내';
    if (_partnerId != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('누구의 사진 자동 등록 일정을 삭제할까요?'),
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
      if (choice == null || !mounted) return;
      if (choice == 'partner') {
        targetUserId = _partnerId!;
        targetLabel = '${_partnerNickname ?? '파트너'}의';
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사진 자동 등록 일정 삭제'),
        content: Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월의 $targetLabel 사진 자동 등록 일정을 모두 삭제하시겠습니까?\n구글 캘린더 연동 일정은 삭제되지 않습니다.\n이 작업은 되돌릴 수 없습니다.',
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
                    ? '사진 자동 등록 일정 $count개를 삭제했습니다.'
                    : '삭제할 사진 자동 등록 일정이 없습니다.',
              ),
            ),
          );
        }
      } catch (e) {
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사진 자동 등록 일정 삭제 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  Future<void> _deleteGoogleCalendarMonthSchedules() async {
    if (_myUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구글 캘린더 일정 삭제'),
        content: Text(
          '${_focusedMonth.year}년 ${_focusedMonth.month}월의 내 구글 캘린더 연동 일정을 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
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
        final count = await _service.deleteMyGoogleCalendarMonthSchedules(
          _focusedMonth,
          _coupleId!,
        );
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
            const SnackBar(content: Text('구글 캘린더 일정 삭제 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  void _showFabMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('일정 추가'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddSheet(null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('자동 등록'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AutoRegistrationScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(DateTime? date) async {
    if (_coupleId == null || _myUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('커플 연결이 필요합니다.')),
      );
      return;
    }
    final result = await ScheduleAddSheet.show(
      context,
      initialDate: date ?? _selectedDay,
      myUserId: _myUserId!,
      coupleId: _coupleId!,
      partnerId: _partnerId,
      partnerNickname: _partnerNickname,
    );
    if (result != null && mounted) {
      try {
        await _service.addSchedule(result);
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정을 추가했습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('일정 추가 실패: $e')),
          );
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
                '${_focusedMonth.year}년',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.people_outlined,
              color: _partnerGrayMode ? AppTheme.primary : AppTheme.textSecondary,
            ),
            tooltip: _partnerGrayMode ? '상대방 색상 구분 켜짐' : '상대방 색상 구분하기',
            onPressed: () => setState(() {
              _partnerGrayMode = !_partnerGrayMode;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, color: AppTheme.primary),
            tooltip: '장소 지도',
            onPressed: () {
              if (_coupleId == null || _myUserId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DateMapScreen(
                    coupleId: _coupleId!,
                    myUserId: _myUserId!,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined,
                color: Color(0xFF4285F4)),
            tooltip: '이달의 구글 캘린더 연동 일정 삭제',
            onPressed: _deleteGoogleCalendarMonthSchedules,
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined,
                color: AppTheme.warning),
            tooltip: '이달의 사진 자동 등록 일정 삭제',
            onPressed: _deleteOcrMonthSchedules,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: AppTheme.error),
            tooltip: '이달의 내 일정 전체 삭제',
            onPressed: _deleteMyMonthSchedules,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // TableCalendar 내부: 헤더 ~52px + 요일행 32px = 84px
                const innerFixed = 52.0 + 32.0;
                final rowH = ((constraints.maxHeight - innerFixed) / 6)
                    .clamp(60.0, 110.0);
                return _buildTableCalendar(rowHeight: rowH);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabMenu,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTableCalendar({double rowHeight = 86}) {
    return TableCalendar<Schedule>(
      key: ValueKey(_partnerGrayMode),
      locale: 'ko_KR',
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime(2030, 12, 31),
      focusedDay: _focusedMonth,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      rowHeight: rowHeight,
      daysOfWeekHeight: 32,
      onDaySelected: (selectedDay, focusedDay) {
        final alreadySelected = isSameDay(_selectedDay, selectedDay);
        setState(() {
          _selectedDay = selectedDay;
          _focusedMonth = focusedDay;
        });
        // 두 번째 탭일 때만 세부 시트 표시
        if (alreadySelected) {
          final events = _getEventsForDay(selectedDay);
          final holidays = _getHolidaysForDay(selectedDay);
          DayDetailSheet.show(
            context,
            date: selectedDay,
            schedules: _service.sortByOwner(events, _myUserId ?? ''),
            holidays: holidays,
            myUserId: _myUserId ?? '',
            partnerNickname: _partnerNickname,
            getColor: _getScheduleColor,
            onEdit: _editScheduleItem,
            onDelete: _deleteScheduleItem,
            onAddTap: () => _showAddSheet(selectedDay),
          );
        }
      },
      onPageChanged: (focusedDay) {
        _focusedMonth = focusedDay;
        _loadHolidays(focusedDay);
        _loadSchedules(focusedDay);
      },
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(color: Color(0xFFE53935)),
      ),
      calendarBuilders: CalendarBuilders<Schedule>(
        defaultBuilder: (ctx, day, _) =>
            _buildCell(day, isSelected: false, isToday: false),
        selectedBuilder: (ctx, day, _) =>
            _buildCell(day, isSelected: true, isToday: false),
        todayBuilder: (ctx, day, _) =>
            _buildCell(day, isSelected: false, isToday: true),
        markerBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCell(DateTime day, {required bool isSelected, required bool isToday}) {
    final events = _getEventsForDay(day);
    final sorted = _service.sortByOwner(events, _myUserId ?? '');
    return _CalendarCell(
      day: day,
      isSelected: isSelected,
      isToday: isToday,
      events: sorted,
      holidays: _getHolidaysForDay(day),
      getColor: _getScheduleColor,
      onEventTap: _onScheduleTap,
      myUserId: _myUserId ?? '',
      partnerGrayMode: _partnerGrayMode,
    );
  }
}

// ────────────────────────────────────────────────────
// 달력 셀 — 날짜 숫자 + 일정 바 최대 3개
// ────────────────────────────────────────────────────
class _CalendarCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final List<Schedule> events;
  final List<Holiday> holidays;
  final Color Function(Schedule) getColor;
  final void Function(Schedule) onEventTap;
  final bool partnerGrayMode;
  final String myUserId;

  const _CalendarCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.events,
    required this.holidays,
    required this.getColor,
    required this.onEventTap,
    required this.myUserId,
    this.partnerGrayMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSunday = day.weekday == DateTime.sunday;
    final isSaturday = day.weekday == DateTime.saturday;
    final isPublicHoliday = holidays.any((h) => h.type == HolidayType.publicHoliday);

    Color numColor = AppTheme.textPrimary;
    if (isPublicHoliday || isSunday) numColor = const Color(0xFFE53935);
    if (isSaturday) numColor = const Color(0xFF1565C0);
    if (isSelected) numColor = Colors.white;

    BoxDecoration numDecoration;
    if (isSelected) {
      numDecoration = const BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      numDecoration = BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      );
    } else {
      numDecoration = const BoxDecoration();
    }

    // 우리(couple) 일정 여부 — 하트 뱃지 표시용
    final hasCoupleEvent = events.any((s) => s.ownerType == 'couple');

    // 비기념일 일정만 바로 표시 (기념일은 별도 핑크 바)
    final nonAnniv = events.where((s) => !s.isAnniversary).toList();
    final anniv = events.where((s) => s.isAnniversary).toList();
    // 연속 일정(다중일)을 맨 앞으로 정렬 → 단일 이벤트에 의해 바가 끊기지 않도록
    nonAnniv.sort((a, b) {
      final aStart = a.startDate ?? a.date;
      final aEnd = a.endDate ?? aStart;
      final bStart = b.startDate ?? b.date;
      final bEnd = b.endDate ?? bStart;
      final aMulti = !isSameDay(aStart, aEnd);
      final bMulti = !isSameDay(bStart, bEnd);
      if (aMulti && !bMulti) return -1;
      if (!aMulti && bMulti) return 1;
      return 0;
    });
    final displayEvents = [...anniv, ...nonAnniv]; // 기념일을 맨 위에
    final visibleEvents = displayEvents.take(3).toList();
    final overflowCount = displayEvents.length - 3;

    return Container(
      padding: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
          right: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 날짜 숫자 (우리 일정 있으면 하트 뱃지 오버레이)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: numDecoration,
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          color: numColor,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (hasCoupleEvent)
                      Positioned(
                        right: -3,
                        bottom: -2,
                        child: Icon(
                          Icons.favorite,
                          size: 8,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppTheme.accent,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 일정 바들
          ...visibleEvents.map((s) {
            final normDay = DateTime(day.year, day.month, day.day);
            final start = s.startDate ?? s.date;
            final end = s.endDate ?? start;
            final normStart = DateTime(start.year, start.month, start.day);
            final normEnd = DateTime(end.year, end.month, end.day);

            // 진짜 시작/끝일 때만 모서리 처리 → 주 경계에서 edge-to-edge로 연결됨
            final isStart = normDay == normStart;
            final isEnd = normDay == normEnd;

            // 이 주 행에서 보이는 구간의 중앙 셀만 제목 표시
            final weekRowStart = normDay.subtract(
              Duration(days: normDay.weekday - 1), // 이번 주 월요일
            );
            final weekRowEnd = weekRowStart.add(const Duration(days: 6));
            final visStart =
                normStart.isAfter(weekRowStart) ? normStart : weekRowStart;
            final visEnd =
                normEnd.isBefore(weekRowEnd) ? normEnd : weekRowEnd;
            final spanDays = visEnd.difference(visStart).inDays + 1;
            final titleDay = visStart.add(Duration(days: spanDays ~/ 2));
            final showTitle = normDay == titleDay;

            final barColor = s.isAnniversary
                ? AppTheme.accent
                : (partnerGrayMode && s.ownerType != 'couple' && s.userId != myUserId
                    ? Colors.grey.shade400
                    : getColor(s));
            return _EventBar(
              schedule: s,
              color: barColor,
              onTap: s.isAnniversary ? null : () => onEventTap(s),
              isStart: isStart,
              isEnd: isEnd,
              showTitle: showTitle,
            );
          }),

          // +N 더보기
          if (overflowCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                '+$overflowCount',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.right,
              ),
            ),

          // 공휴일명 — 셀 하단에 표시 (바 연속성 유지)
          if (holidays.any((h) => h.type == HolidayType.publicHoliday))
            Builder(builder: (context) {
              final h = holidays
                  .firstWhere((h) => h.type == HolidayType.publicHoliday);
              return Padding(
                padding: const EdgeInsets.only(top: 1, left: 2, right: 2),
                child: Text(
                  h.name.length > 4 ? h.name.substring(0, 4) : h.name,
                  style: TextStyle(
                    fontSize: 7,
                    color: isSelected ? Colors.white70 : h.color,
                  ),
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EventBar extends StatelessWidget {
  final Schedule schedule;
  final Color color;
  final VoidCallback? onTap;
  final bool isStart;
  final bool isEnd;
  final bool showTitle;

  const _EventBar({
    required this.schedule,
    required this.color,
    this.onTap,
    this.isStart = true,
    this.isEnd = true,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final margin = EdgeInsets.fromLTRB(
      isStart ? 2 : 0,
      1,
      isEnd ? 2 : 0,
      0,
    );
    final borderRadius = BorderRadius.only(
      topLeft: isStart ? const Radius.circular(3) : Radius.zero,
      bottomLeft: isStart ? const Radius.circular(3) : Radius.zero,
      topRight: isEnd ? const Radius.circular(3) : Radius.zero,
      bottomRight: isEnd ? const Radius.circular(3) : Radius.zero,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 15,
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
        ),
        alignment: Alignment.center,
        child: showTitle
            ? Text(
                schedule.title ?? schedule.workType ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

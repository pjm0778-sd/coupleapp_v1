import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../core/holiday_service.dart';
import '../../../shared/models/schedule.dart';
import '../../profile/models/shift_time.dart';
import '../services/schedule_service.dart';
import '../widgets/schedule_add_sheet.dart';
import '../widgets/day_detail_sheet.dart';
import 'date_map_screen.dart';
import '../../../features/schedule/screens/auto_registration_screen.dart';
import '../../settings/screens/settings_screen.dart';
import 'calendar_settings_screen.dart';

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
  bool _showTutorial = false;
  List<ShiftTime> _quickShiftTimes = [];
  ShiftTime? _selectedQuickShift;
  // 달력설정에서 만든 사용자 템플릿 목록
  List<({String id, String name, List<ShiftTime> shiftTimes})> _userTemplates = [];
  String? _activeTemplateName;  // 현재 선택된 템플릿 이름
  bool _easyAddMode = false;
  final Map<DateTime, ShiftTime> _pendingQuickAdds = {};

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
    await _loadQuickShiftTimes();
    await _loadSchedules(_focusedMonth);

    // 첫 방문 튜토리얼
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('calendar_tutorial_shown') ?? false;
    if (!shown && mounted) {
      setState(() => _showTutorial = true);
    }

    // 홈화면에서 특정 날짜로 진입한 경우 자동으로 상세 시트 오픈
    if (widget.initialDate != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDayDetail(_selectedDay);
      });
    }
  }

  Future<void> _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('calendar_tutorial_shown', true);
    if (mounted) setState(() => _showTutorial = false);
  }

  static const _userTemplatePrefsKey = 'calendar_user_template_types_v1';

  Future<void> _loadQuickShiftTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userTemplatePrefsKey);

    List<({String id, String name, List<ShiftTime> shiftTimes})> templates = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map<String, dynamic>) continue;
            final rawTimes = item['shift_times'];
            final times = rawTimes is List
                ? rawTimes
                    .whereType<Map<String, dynamic>>()
                    .map(ShiftTime.fromMap)
                    .toList()
                : <ShiftTime>[];
            templates.add((
              id: item['id'] as String? ?? '',
              name: item['name'] as String? ?? '템플릿',
              shiftTimes: times,
            ));
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    // 첫 번째 템플릿을 기본 선택
    final firstTemplate = templates.isNotEmpty ? templates.first : null;
    final times = firstTemplate?.shiftTimes ?? <ShiftTime>[];

    setState(() {
      _userTemplates = templates;
      _activeTemplateName = firstTemplate?.name;
      _quickShiftTimes = times;
      if (times.isEmpty) {
        _selectedQuickShift = null;
      } else if (_selectedQuickShift == null ||
          !times.any((t) => t.shiftType == _selectedQuickShift!.shiftType)) {
        _selectedQuickShift = times.first;
      }
    });
  }

  String _quickCategory(ShiftTime shift) {
    final code = shift.shiftType.trim().toLowerCase();
    if (code == 'x' || code == 'off') {
      return '쉬는날';
    }
    return '근무';
  }

  String _quickColorHex(ShiftTime shift) {
    final custom = shift.colorHex?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom.startsWith('#') ? custom : '#$custom';
    }

    final code = shift.shiftType.trim().toLowerCase();

    if (code == 'x' || code == 'off') {
      return '#BDBDBD';
    }

    if (code == 'd' || code == 'day') return '#4CAF50';
    if (code == 'e') return '#2196F3';
    if (code == 'm') return '#FF9800';
    if (code == 'n' || code == 'night') return '#7E57C2';

    // 사용자 정의 코드(F 등)는 기본 근무색으로 저장
    return '#4CAF50';
  }

  Schedule? _findEditableQuickSchedule(DateTime day) {
    return _getEventsForDay(day).cast<Schedule?>().firstWhere(
      (event) =>
          event != null &&
          event.userId == _myUserId &&
          !event.isAnniversary &&
          !event.isDate &&
          ((event.workType?.trim().isNotEmpty ?? false) ||
              event.category == '근무' ||
              event.category == '쉬는날'),
      orElse: () => null,
    );
  }

  Schedule _buildQuickScheduleFromShift({
    required DateTime date,
    required ShiftTime shift,
    Schedule? base,
  }) {
    return (base ??
            Schedule(
              id: 'pending_${date.toIso8601String()}_${shift.shiftType}',
              userId: _myUserId ?? '',
              coupleId: _coupleId,
              date: date,
              startDate: date,
              endDate: date,
            ))
        .copyWith(
      title: shift.shiftType,
      workType: shift.shiftType,
      category: _quickCategory(shift),
      colorHex: _quickColorHex(shift),
      startTime: shift.isAllDay
          ? null
          : TimeOfDay(hour: shift.startHour, minute: shift.startMinute),
      endTime: shift.isAllDay
          ? null
          : TimeOfDay(hour: shift.endHour, minute: shift.endMinute),
    );
  }

  bool _isSameTiming(Schedule schedule, ShiftTime shift) {
    if (shift.isAllDay) {
      return schedule.startTime == null && schedule.endTime == null;
    }
    return schedule.startTime?.hour == shift.startHour &&
        schedule.startTime?.minute == shift.startMinute &&
        schedule.endTime?.hour == shift.endHour &&
        schedule.endTime?.minute == shift.endMinute;
  }

  void _toggleQuickAddOnDate(DateTime day) {
    if (_selectedQuickShift == null) return;
    final date = DateTime(day.year, day.month, day.day);
    final shift = _selectedQuickShift!;
    final existing = _pendingQuickAdds[date];
    final savedSchedule = _findEditableQuickSchedule(date);
    var message = '';

    setState(() {
      if (existing == null) {
        if (savedSchedule != null && savedSchedule.workType == shift.shiftType) {
          message = '${date.month}/${date.day} 이미 ${shift.shiftType}로 저장되어 있습니다';
          return;
        }
        _pendingQuickAdds[date] = shift;
        message = savedSchedule == null
            ? '${date.month}/${date.day} ${shift.shiftType} 임시 추가'
            : '${date.month}/${date.day} ${shift.shiftType}로 변경 예정';
      } else if (existing.shiftType == shift.shiftType) {
        _pendingQuickAdds.remove(date);
        message = savedSchedule == null
            ? '${date.month}/${date.day} 임시 추가 해제'
            : '${date.month}/${date.day} 변경 취소';
      } else {
        _pendingQuickAdds[date] = shift;
        message = '${date.month}/${date.day} ${shift.shiftType}로 변경';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(milliseconds: 900)),
    );
  }

  Schedule _buildPendingQuickSchedule(DateTime date, ShiftTime shift) {
    return _buildQuickScheduleFromShift(
      date: date,
      shift: shift,
      base: _findEditableQuickSchedule(date),
    );
  }

  List<Schedule> _getDisplayEventsForDay(DateTime day) {
    final events = List<Schedule>.from(_getEventsForDay(day));
    final key = DateTime(day.year, day.month, day.day);
    final pendingShift = _pendingQuickAdds[key];
    if (pendingShift != null) {
      final editable = _findEditableQuickSchedule(key);
      if (editable != null) {
        final index = events.indexWhere((event) => event.id == editable.id);
        final replacement = _buildPendingQuickSchedule(key, pendingShift);
        if (index >= 0) {
          events[index] = replacement;
        } else {
          events.add(replacement);
        }
      } else {
        events.add(_buildPendingQuickSchedule(key, pendingShift));
      }
    }
    return events;
  }

  Future<void> _savePendingQuickAdds() async {
    if (_coupleId == null || _myUserId == null) return;
    if (_pendingQuickAdds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장할 템플릿 추가 항목이 없습니다.')));
      return;
    }

    setState(() => _isLoading = true);
    int saved = 0;
    int updated = 0;
    int skipped = 0;

    final entries = _pendingQuickAdds.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in entries) {
      final date = entry.key;
      final shift = entry.value;
      final existingSchedule = _findEditableQuickSchedule(date);

      if (existingSchedule != null) {
        final sameAsExisting =
            existingSchedule.workType == shift.shiftType &&
            _isSameTiming(existingSchedule, shift);
        if (sameAsExisting) {
          skipped++;
          continue;
        }

        try {
          final updatedSchedule = _buildQuickScheduleFromShift(
            date: date,
            shift: shift,
            base: existingSchedule,
          );
          await _service.updateSchedule(existingSchedule.id, updatedSchedule.toMap());
          updated++;
        } catch (_) {
          // 개별 항목 실패는 건너뛰고 나머지 계속 저장
        }
        continue;
      }

      final dayEvents = _getEventsForDay(date);
      final duplicate = dayEvents.any(
        (e) =>
            e.userId == _myUserId &&
            e.workType == shift.shiftType &&
        _isSameTiming(e, shift),
      );
      if (duplicate) {
        skipped++;
        continue;
      }

      final schedule = Schedule(
        id: '',
        userId: _myUserId!,
        coupleId: _coupleId,
        date: date,
        startDate: date,
        endDate: date,
        title: shift.shiftType,
        workType: shift.shiftType,
        category: _quickCategory(shift),
        colorHex: _quickColorHex(shift),
        startTime: TimeOfDay(hour: shift.startHour, minute: shift.startMinute),
        endTime: TimeOfDay(hour: shift.endHour, minute: shift.endMinute),
      );

      try {
        await _service.addSchedule(schedule);
        saved++;
      } catch (_) {
        // 개별 항목 실패는 건너뛰고 나머지 계속 저장
      }
    }

    await _loadSchedules(_focusedMonth);
    if (!mounted) return;
    setState(() {
      _pendingQuickAdds.clear();
      _easyAddMode = false;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          skipped > 0
              ? '템플릿 추가 $saved개, 변경 $updated개, 중복 $skipped개 제외'
              : '템플릿 추가 $saved개, 변경 $updated개 완료',
        ),
      ),
    );
  }

  Future<void> _exitEasyAddMode() async {
    if (_pendingQuickAdds.isEmpty) {
      if (!mounted) return;
      setState(() => _easyAddMode = false);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('저장하지 않고 종료할까요?'),
        content: Text(
          '임시로 추가한 일정 ${_pendingQuickAdds.length}건이 저장되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 편집'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장 안 하고 종료'),
          ),
        ],
      ),
    );

    if (discard != true || !mounted) return;
    setState(() {
      _pendingQuickAdds.clear();
      _easyAddMode = false;
    });
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
    if (!mounted) return;

    if (_coupleId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final prevMonth = DateTime(month.year, month.month - 1);
      final nextMonth = DateTime(month.year, month.month + 1);
      final results = await Future.wait([
        _service.getMonthSchedules(_coupleId!, prevMonth),
        _service.getMonthSchedules(_coupleId!, month),
        _service.getMonthSchedules(_coupleId!, nextMonth),
      ]);
      final list = [...results[0], ...results[1], ...results[2]];
      // 중복 제거 (id 기준)
      final seen = <String>{};
      list.retainWhere((s) => seen.add(s.id));
      if (!mounted) return;

      // 기념일 계산 (100일, 200일, 1주년 등) — 현재 달 기준
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

      if (!mounted) return;
      setState(() {
        _events = map;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
      case '쉬는날':
        return const Color(0xFFBDBDBD);
      case '기념일':
        return AppTheme.primary;
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

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${_focusedMonth.year}년 ${_focusedMonth.month}월 일정 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.red,
              ),
              title: const Text('전체 삭제'),
              subtitle: const Text('이달 내 모든 내 일정 삭제'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () => Navigator.pop(context, 'all'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.title_outlined, color: Colors.orange),
              title: const Text('제목으로 삭제'),
              subtitle: const Text('특정 제목의 일정만 삭제'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
      if (!mounted) return;
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다.')));
        }
      }
    } else if (choice == 'title') {
      if (!mounted) return;
      final controller = TextEditingController();
      final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                count > 0 ? '"$title" 일정 $count개를 삭제했습니다.' : '삭제할 일정이 없습니다.',
              ),
            ),
          );
        }
      } catch (e) {
        await _loadSchedules(_focusedMonth);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('일정 삭제 중 오류가 발생했습니다.')));
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
              leading: const Icon(Icons.auto_fix_high_outlined),
              title: const Text('템플릿으로 추가'),
              onTap: () {
                Navigator.pop(ctx);
                if (_userTemplates.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('달력 설정에서 내 템플릿을 먼저 만들어 주세요.'),
                    ),
                  );
                  return;
                }
                setState(() {
                  _easyAddMode = true;
                  _pendingQuickAdds.clear();
                  // 기본 선택: 첫 번째 템플릿
                  if (_activeTemplateName == null && _userTemplates.isNotEmpty) {
                    final first = _userTemplates.first;
                    _activeTemplateName = first.name;
                    _quickShiftTimes = first.shiftTimes;
                    _selectedQuickShift =
                        first.shiftTimes.isNotEmpty ? first.shiftTimes.first : null;
                  } else if (_quickShiftTimes.isNotEmpty) {
                    _selectedQuickShift ??= _quickShiftTimes.first;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('일정 코드를 선택하고 날짜를 눌러 추가하세요.'),
                  ),
                );
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

  /// 내 템플릿 선택 바텀시트
  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '템플릿 선택',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ..._userTemplates.map((template) {
                final isActive = template.name == _activeTemplateName;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeTemplateName = template.name;
                      _quickShiftTimes = template.shiftTimes;
                      _selectedQuickShift = template.shiftTimes.isNotEmpty
                          ? template.shiftTimes.first
                          : null;
                      _pendingQuickAdds.clear(); // 템플릿 바꾸면 대기 초기화
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.accentLight : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? AppTheme.primary : AppTheme.border,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? AppTheme.primary
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '항목 ${template.shiftTimes.length}개',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(DateTime? date) async {
    if (_coupleId == null || _myUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('커플 연결이 필요합니다.')));
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        toolbarHeight: 68,
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
            ],
          ),
        ),
        centerTitle: false,
        actions: [
          _LabeledAppBarButton(
            icon: Icons.tune_outlined,
            label: '달력설정',
            color: AppTheme.textTertiary,
            tooltip: '달력 설정',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CalendarSettingsScreen(),
                ),
              );
              await _loadQuickShiftTimes();
            },
          ),
          _LabeledAppBarButton(
            icon: Icons.settings_outlined,
            label: '설정',
            color: AppTheme.textTertiary,
            tooltip: '설정',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _LabeledAppBarButton(
            icon: Icons.people_outlined,
            label: '내 일정',
            color: _partnerGrayMode ? AppTheme.primary : AppTheme.textTertiary,
            tooltip: _partnerGrayMode ? '상대방 색상 구분 켜짐' : '상대방 색상 구분하기',
            onPressed: () =>
                setState(() => _partnerGrayMode = !_partnerGrayMode),
          ),
          _LabeledAppBarButton(
            icon: Icons.map_outlined,
            label: '장소지도',
            color: AppTheme.primary,
            tooltip: '데이트 장소를 지도로 보기',
            onPressed: () {
              if (_coupleId == null || _myUserId == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DateMapScreen(coupleId: _coupleId!, myUserId: _myUserId!),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: '더보기',
            color: AppTheme.surface,
            icon: Icon(Icons.more_horiz_rounded, color: AppTheme.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'delete_google':
                  _deleteGoogleCalendarMonthSchedules();
                  break;
                case 'delete_ocr':
                  _deleteOcrMonthSchedules();
                  break;
                case 'delete_all':
                  _deleteMyMonthSchedules();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'delete_google',
                child: _CalendarMenuItem(
                  icon: Icons.calendar_month_outlined,
                  label: '구글 연동 일정 삭제',
                  color: Color(0xFF4285F4),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete_ocr',
                child: _CalendarMenuItem(
                  icon: Icons.document_scanner_outlined,
                  label: '자동등록 일정 삭제',
                  color: AppTheme.warning,
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete_all',
                child: _CalendarMenuItem(
                  icon: Icons.delete_sweep_outlined,
                  label: '이달 내 일정 전체 삭제',
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: AppTheme.pageGradient)),
          Column(
            children: [
              if (_isLoading)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.primaryLight,
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    _easyAddMode ? 28 : 12,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: const [AppTheme.cardShadow],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const innerFixed = 52.0 + 32.0;
                        final textScale = MediaQuery.textScalerOf(context)
                            .scale(1.0);

                        // 하단 쉬운추가 바/큰 글꼴/작은 화면에서 월별 overflow를 줄이기 위한 보정
                        double adaptiveFixed = innerFixed;
                        if (_easyAddMode) adaptiveFixed += 8;
                        if (textScale > 1.05) {
                          adaptiveFixed += (textScale - 1.05) * 18;
                        }
                        if (constraints.maxHeight < 620) {
                          adaptiveFixed += 10;
                        }

                        final rowH = ((constraints.maxHeight - adaptiveFixed) / 6)
                            .clamp(52.0, 110.0);
                        return _buildTableCalendar(rowHeight: rowH);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showTutorial)
            _CalendarTutorialOverlay(onDismiss: _dismissTutorial),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabMenu,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _easyAddMode
          ? SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                  boxShadow: const [AppTheme.subtleShadow],
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_fix_high_outlined,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _selectedQuickShift != null
                                ? '선택: ${_selectedQuickShift!.shiftType} · 대기 ${_pendingQuickAdds.length}건'
                                : '템플릿으로 추가',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _exitEasyAddMode,
                          child: const Text('종료'),
                        ),
                        const SizedBox(width: 4),
                        ElevatedButton(
                          onPressed:
                              _pendingQuickAdds.isEmpty ? null : _savePendingQuickAdds,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('최종 저장'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 템플릿 선택 행 (템플릿이 여러 개일 때)
                    if (_userTemplates.length > 1)
                      GestureDetector(
                        onTap: _showTemplatePicker,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.folder_outlined,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _activeTemplateName ?? '템플릿 선택',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.expand_more,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _quickShiftTimes.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final shift = _quickShiftTimes[i];
                          final selected =
                              _selectedQuickShift?.shiftType == shift.shiftType;
                          return ChoiceChip(
                            label: Text(shift.shiftType),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedQuickShift = shift);
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            selectedColor: AppTheme.primaryLight,
                            labelStyle: TextStyle(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.border,
                            ),
                            backgroundColor: AppTheme.surface,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
      eventLoader: _getDisplayEventsForDay,
      rowHeight: rowHeight,
      daysOfWeekHeight: 32,
      onDaySelected: (selectedDay, focusedDay) async {
        final alreadySelected = isSameDay(_selectedDay, selectedDay);
        setState(() {
          _selectedDay = selectedDay;
          _focusedMonth = focusedDay;
        });

        if (_easyAddMode) {
          _toggleQuickAddOnDate(selectedDay);
          return;
        }

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
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: AppTheme.textSecondary,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        weekendStyle: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      calendarStyle: const CalendarStyle(
        outsideDaysVisible: true,
        weekendTextStyle: TextStyle(color: Color(0xFFFF6B6B)),
        defaultDecoration: BoxDecoration(color: Colors.transparent),
        todayDecoration: BoxDecoration(color: Colors.transparent),
        selectedDecoration: BoxDecoration(color: Colors.transparent),
      ),
      calendarBuilders: CalendarBuilders<Schedule>(
        defaultBuilder: (ctx, day, _) =>
            _buildCell(day, isSelected: false, isToday: false),
        selectedBuilder: (ctx, day, _) =>
            _buildCell(day, isSelected: true, isToday: false),
        todayBuilder: (ctx, day, _) =>
            _buildCell(day, isSelected: false, isToday: true),
        outsideBuilder: (ctx, day, _) =>
            _buildCell(day, isSelected: false, isToday: false, isOutside: true),
        markerBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCell(
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    bool isOutside = false,
  }) {
    final events = _getDisplayEventsForDay(day);
    final sorted = _service.sortByOwner(events, _myUserId ?? '');
    return _CalendarCell(
      day: day,
      isSelected: isSelected,
      isToday: isToday,
      isOutside: isOutside,
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
  final bool isOutside;
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
    this.isOutside = false,
    this.partnerGrayMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSunday = day.weekday == DateTime.sunday;
    final isSaturday = day.weekday == DateTime.saturday;
    final isPublicHoliday = holidays.any(
      (h) => h.type == HolidayType.publicHoliday,
    );

    Color numColor = AppTheme.textPrimary;
    if (isPublicHoliday || isSunday) numColor = const Color(0xFFD66B6B);
    if (isSaturday) numColor = AppTheme.accent;
    if (isSelected) numColor = Colors.white;

    BoxDecoration numDecoration;
    if (isSelected) {
      numDecoration = const BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      numDecoration = BoxDecoration(
        color: AppTheme.primaryLight,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.24)),
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

    final cell = Container(
      padding: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.7),
          right: BorderSide(color: AppTheme.border, width: 0.7),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 셀 실측 높이에 따라 표시 요소를 줄여 overflow 방지
          int dynamicMaxBars;
          if (constraints.maxHeight < 72) {
            dynamicMaxBars = 0;
          } else if (constraints.maxHeight < 90) {
            dynamicMaxBars = 1;
          } else if (constraints.maxHeight < 104) {
            dynamicMaxBars = 2;
          } else {
            dynamicMaxBars = 3;
          }
          if (isPublicHoliday) dynamicMaxBars -= 1;
          if (dynamicMaxBars < 0) dynamicMaxBars = 0;

          final visibleEvents = displayEvents.take(dynamicMaxBars).toList();
          final overflowCount = displayEvents.length - dynamicMaxBars;
          final showOverflow =
              overflowCount > 0 &&
              !isPublicHoliday &&
              constraints.maxHeight >= 98;
          final showHolidayLabel =
              isPublicHoliday && constraints.maxHeight >= 94;

          return Column(
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
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
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
                              : AppTheme.primary,
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
            final visStart = normStart.isAfter(weekRowStart)
                ? normStart
                : weekRowStart;
            final visEnd = normEnd.isBefore(weekRowEnd) ? normEnd : weekRowEnd;
            final spanDays = visEnd.difference(visStart).inDays + 1;
            final titleDay = visStart.add(Duration(days: spanDays ~/ 2));
            final showTitle = normDay == titleDay;

            final barColor = s.isAnniversary
                ? AppTheme.primary
                : (partnerGrayMode &&
                          s.ownerType != 'couple' &&
                          s.userId != myUserId
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
          if (showOverflow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                '+$overflowCount',
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textTertiary,
                ),
                textAlign: TextAlign.right,
              ),
            ),

          // 공휴일명 — 셀 하단에 표시 (바 연속성 유지)
          if (showHolidayLabel)
            Builder(
              builder: (context) {
                final h = holidays.firstWhere(
                  (h) => h.type == HolidayType.publicHoliday,
                );
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
              },
            ),
            ],
          );
        },
      ),
    );
    return isOutside
        ? Opacity(opacity: 0.35, child: cell)
        : cell;
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
    final margin = EdgeInsets.fromLTRB(isStart ? 2 : 0, 1, isEnd ? 2 : 0, 0);
    final borderRadius = BorderRadius.only(
      topLeft: isStart ? const Radius.circular(3) : Radius.zero,
      bottomLeft: isStart ? const Radius.circular(3) : Radius.zero,
      topRight: isEnd ? const Radius.circular(3) : Radius.zero,
      bottomRight: isEnd ? const Radius.circular(3) : Radius.zero,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 13,
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
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

class _CalendarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CalendarMenuItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        ),
      ],
    );
  }
}

// ── AppBar 아이콘 + 라벨 버튼 ─────────────────────────────
class _LabeledAppBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _LabeledAppBarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 앱 기능 첫 방문 튜토리얼 오버레이 ─────────────────────────
class _CalendarTutorialOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const _CalendarTutorialOverlay({required this.onDismiss});

  @override
  State<_CalendarTutorialOverlay> createState() =>
      _CalendarTutorialOverlayState();
}

class _CalendarTutorialOverlayState extends State<_CalendarTutorialOverlay> {
  int _page = 0;

  static const _features = [
    (
      '📅',
      '일정 공유',
      '+ 버튼으로 내 일정을 등록하면\n파트너와 실시간으로 공유돼요.\n서로의 D·E·N 근무도 한눈에 볼 수 있어요.',
    ),
    (
      '📸',
      '사진 자동 등록',
      '일정표 사진을 찍으면 OCR로\n한 달치 일정이 자동 등록돼요.\n설정에서 템플릿 항목을 미리 설정해 두세요.',
    ),
    ('📍', '장소 지도', '지도 버튼을 누르면 함께 갔던\n데이트 장소들을 지도에서 볼 수 있어요.'),
    (
      '🗑️',
      '일정 삭제 버튼',
      '상단 버튼으로 이달의 구글 캘린더\n연동 일정·OCR 일정·내 일정을\n한 번에 삭제할 수 있어요.',
    ),
    (
      '🌤️',
      '홈 화면 기능',
      '홈에서는 날씨·교통·기념일·\n다음 데이트 D-day를 확인할 수 있어요.\n설정에서 도시와 연애 스타일을 설정해 보세요.',
    ),
    ('🎉', '기념일 자동 표시', '사귄 날짜를 등록하면 100일·1주년 등\n특별한 기념일이 달력에 자동으로 표시돼요.'),
  ];

  @override
  Widget build(BuildContext context) {
    final feature = _features[_page];
    final isLast = _page == _features.length - 1;

    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.42),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_features.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppTheme.primary
                                : AppTheme.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Text(feature.$1, style: const TextStyle(fontSize: 52)),
                    const SizedBox(height: 12),
                    Text(
                      feature.$2,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      feature.$3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        if (_page > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _page--),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('이전'),
                            ),
                          ),
                        if (_page > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isLast
                                ? widget.onDismiss
                                : () => setState(() => _page++),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isLast ? '시작하기 🎉' : '다음',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onDismiss,
                      child: const Text(
                        '건너뛰기',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

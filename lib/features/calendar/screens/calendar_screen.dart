import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';
import '../services/schedule_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = ScheduleService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  String? _coupleId;
  String? _myUserId;
  Map<DateTime, List<Schedule>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _myUserId = supabase.auth.currentUser?.id;
    _init();
  }

  Future<void> _init() async {
    _coupleId = await _service.getCoupleId();
    await _loadSchedules(_focusedDay);
  }

  Future<void> _loadSchedules(DateTime month) async {
    if (_coupleId == null) return;
    setState(() => _isLoading = true);
    final list = await _service.getMonthSchedules(_coupleId!, month);
    final map = <DateTime, List<Schedule>>{};
    for (final s in list) {
      final key = DateTime(s.date.year, s.date.month, s.date.day);
      map.putIfAbsent(key, () => []).add(s);
    }
    if (mounted) setState(() { _events = map; _isLoading = false; });
  }

  List<Schedule> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  Color _hexToColor(String? hex) {
    if (hex == null) return AppTheme.primary;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  void _showDeleteMonthDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이번 달 일정 전체 삭제'),
        content: Text('${_focusedDay.month}월의 모든 일정을 삭제할까요?\n삭제된 일정은 복구할 수 없습니다.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (_coupleId != null) {
                await _service.deleteMonthSchedules(_coupleId!, _focusedDay);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadSchedules(_focusedDay);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(DateTime date) {
    final workTypeController = TextEditingController();
    Color selectedColor = const Color(0xFF448AFF);
    bool isDatePlan = false;

    final presetColors = [
      const Color(0xFF448AFF), const Color(0xFFFF5252),
      const Color(0xFF69F0AE), const Color(0xFFFFCA28),
      const Color(0xFFE040FB), const Color(0xFF00BFA5),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${date.month}월 ${date.day}일',
                    style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppTheme.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 색상 선택
              const Text('색상', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: presetColors.map((c) {
                  final sel = selectedColor.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel ? Border.all(color: AppTheme.primary, width: 2.5) : null,
                      ),
                      child: sel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 근무 형태
              const Text('근무 형태 / 메모', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: workTypeController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '예) 나이트, 휴무, 데이트...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              // 데이트 여부
              Row(
                children: [
                  Checkbox(
                    value: isDatePlan,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setSheet(() => isDatePlan = v ?? false),
                  ),
                  const Text('데이트 일정', style: TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final hex = '#${selectedColor.r.round().toRadixString(16).padLeft(2,'0')}${selectedColor.g.round().toRadixString(16).padLeft(2,'0')}${selectedColor.b.round().toRadixString(16).padLeft(2,'0')}'.toUpperCase();
                    final schedule = Schedule(
                      id: '',
                      userId: _myUserId!,
                      coupleId: _coupleId,
                      date: date,
                      workType: workTypeController.text.trim().isEmpty
                          ? null : workTypeController.text.trim(),
                      colorHex: hex,
                      isDate: isDatePlan,
                    );
                    await _service.addSchedule(schedule);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadSchedules(_focusedDay);
                  },
                  child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          TextButton.icon(
            onPressed: () => _showDeleteMonthDialog(),
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: const Text('이번 달 삭제'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 달력
          TableCalendar<Schedule>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _loadSchedules(focused);
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700),
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white),
              markerDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              markersMaxCount: 4,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (ctx, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: events.take(4).map((e) {
                    final isMe = e.userId == _myUserId;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: e.colorHex != null
                            ? _hexToColor(e.colorHex)
                            : (isMe ? AppTheme.primary : AppTheme.accent),
                        shape: isMe ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: isMe ? null : BorderRadius.circular(2),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 선택된 날짜 일정 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : selectedEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_note_outlined,
                                color: AppTheme.textSecondary, size: 32),
                            const SizedBox(height: 8),
                            const Text('일정이 없어요',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: () => _showAddDialog(_selectedDay),
                              child: const Text('+ 일정 추가'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: selectedEvents.length,
                        separatorBuilder: (_, i2) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = selectedEvents[i];
                          final isMe = s.userId == _myUserId;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(
                                    color: _hexToColor(s.colorHex),
                                    shape: isMe
                                        ? BoxShape.circle
                                        : BoxShape.rectangle,
                                    borderRadius: isMe
                                        ? null
                                        : BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.workType ?? (s.isDate ? '데이트' : '일정'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (s.note != null) ...[
                                        const SizedBox(height: 2),
                                        Text(s.note!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary)),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppTheme.primary.withAlpha(20)
                                        : AppTheme.accent.withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isMe ? '나' : '파트너',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isMe
                                          ? AppTheme.primary
                                          : AppTheme.accent,
                                    ),
                                  ),
                                ),
                                if (isMe)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppTheme.textSecondary),
                                    onPressed: () async {
                                      await _service.deleteSchedule(s.id);
                                      await _loadSchedules(_focusedDay);
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () => _showAddDialog(_selectedDay),
        child: const Icon(Icons.add),
      ),
    );
  }
}

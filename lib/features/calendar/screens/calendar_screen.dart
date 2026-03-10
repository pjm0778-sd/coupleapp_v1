import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme.dart';
import '../../../core/emojis.dart';
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

  String _colorToHex(Color color) {
    final r = color.r.round().toRadixString(16).padLeft(2, '0');
    final g = color.g.round().toRadixString(16).padLeft(2, '0');
    final b = color.b.round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
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

  void _showAddDialog(DateTime date, [Schedule? existingSchedule]) {
    final workTypeController = TextEditingController(text: existingSchedule?.workType ?? '');
    final noteController = TextEditingController(text: existingSchedule?.note ?? '');
    Color selectedColor = existingSchedule != null
        ? _hexToColor(existingSchedule.colorHex)
        : AppTheme.scheduleColors.first;
    String selectedEmoji = existingSchedule?.emoji ?? '';
    bool isDatePlan = existingSchedule?.isDate ?? false;
    final customEmojiController = TextEditingController();
    bool showCustomEmoji = false;

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
          child: SingleChildScrollView(
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
                // 색상 선택 (4x5 그리드)
                const Text('색상', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppTheme.scheduleColors.map((c) {
                    final sel = selectedColor.toARGB32() == c.toARGB32();
                    return GestureDetector(
                      onTap: () => setSheet(() => selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: sel ? Border.all(color: AppTheme.primary, width: 3) : null,
                        ),
                        child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // 이모지 선택
                const Text('이모지', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                if (showCustomEmoji) ...[
                  TextField(
                    controller: customEmojiController,
                    decoration: InputDecoration(
                      hintText: '이모지 입력',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (v) {
                      if (v.isNotEmpty) {
                        setSheet(() {
                          selectedEmoji = v;
                          showCustomEmoji = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...Emojis.presets.map((e) {
                        final sel = selectedEmoji == e;
                        return GestureDetector(
                          onTap: () => setSheet(() => selectedEmoji = e),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: sel ? AppTheme.primary.withAlpha(30) : AppTheme.surface,
                              border: sel ? Border.all(color: AppTheme.primary, width: 2) : Border.all(color: AppTheme.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                          ),
                        );
                      }),
                      // 커스텀 이모지 추가 버튼
                      GestureDetector(
                        onTap: () => setSheet(() => showCustomEmoji = true),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: Icon(Icons.add, size: 20, color: AppTheme.textSecondary)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
                // 메모
                const Text('메모', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: workTypeController,
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
                      final hex = _colorToHex(selectedColor);
                      if (existingSchedule != null) {
                        // 수정 모드
                        await _service.updateSchedule(existingSchedule.id, {
                          'work_type': workTypeController.text.trim().isEmpty
                              ? null : workTypeController.text.trim(),
                          'color_hex': hex,
                          'emoji': selectedEmoji.isEmpty ? null : selectedEmoji,
                          'is_date': isDatePlan,
                          'note': noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        });
                      } else {
                        // 추가 모드
                        final schedule = Schedule(
                          id: '',
                          userId: _myUserId!,
                          coupleId: _coupleId,
                          date: date,
                          workType: workTypeController.text.trim().isEmpty
                              ? null : workTypeController.text.trim(),
                          colorHex: hex,
                          isDate: isDatePlan,
                          emoji: selectedEmoji.isEmpty ? null : selectedEmoji,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );
                        await _service.addSchedule(schedule);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadSchedules(_focusedDay);
                    },
                    child: Text(existingSchedule != null ? '수정' : '저장', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 계단식 색상 채움 위젯
  Widget _buildSteppedColors(List<Schedule> schedules) {
    if (schedules.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: List.generate(schedules.length, (i) {
        final schedule = schedules[i];
        final color = _hexToColor(schedule.colorHex);
        // 계단식: 첫 번째는 가장 높게, 마지막은 가장 낮게
        final heightFactor = (schedules.length - i) / schedules.length;
        final stepHeight = 30.0 * heightFactor;

        return Positioned(
          bottom: i * 6.0,
          left: 0,
          right: 0,
          height: stepHeight,
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        );
      }),
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
              defaultDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              weekendDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
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
              defaultBuilder: (ctx, day, focusedDay) {
                final events = _getEventsForDay(day);
                final hasDateSchedule = events.any((s) => s.isDate);
                final emoji = events.isNotEmpty ? events.first.emoji : null;

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasDateSchedule
                          ? AppTheme.dateBorderColor
                          : AppTheme.border,
                      width: hasDateSchedule ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 날짜 숫자 (상단)
                      Positioned(
                        top: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: hasDateSchedule
                                  ? AppTheme.dateBorderColor
                                  : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      // 이모지 (중앙)
                      if (emoji != null && emoji.isNotEmpty)
                        Positioned(
                          top: 28,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      // 계단식 색상 채움 (하단)
                      if (events.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 30,
                          child: _buildSteppedColors(events),
                        ),
                    ],
                  ),
                );
              },
              todayBuilder: (ctx, day, focusedDay) {
                final events = _getEventsForDay(day);
                final hasDateSchedule = events.any((s) => s.isDate);
                final emoji = events.isNotEmpty ? events.first.emoji : null;

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.primary.withAlpha(15),
                    border: Border.all(
                      color: hasDateSchedule
                          ? AppTheme.dateBorderColor
                          : AppTheme.primary,
                      width: hasDateSchedule ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 날짜 숫자 (상단)
                      Positioned(
                        top: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      // 이모지 (중앙)
                      if (emoji != null && emoji.isNotEmpty)
                        Positioned(
                          top: 28,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      // 계단식 색상 채움 (하단)
                      if (events.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 30,
                          child: _buildSteppedColors(events),
                        ),
                    ],
                  ),
                );
              },
              selectedBuilder: (ctx, day, focusedDay) {
                final events = _getEventsForDay(day);
                final hasDateSchedule = events.any((s) => s.isDate);
                final emoji = events.isNotEmpty ? events.first.emoji : null;

                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.primary,
                    border: Border.all(
                      color: hasDateSchedule
                          ? AppTheme.dateBorderColor
                          : AppTheme.primary,
                      width: hasDateSchedule ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // 날짜 숫자 (상단)
                      Positioned(
                        top: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // 이모지 (중앙)
                      if (emoji != null && emoji.isNotEmpty)
                        Positioned(
                          top: 28,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      // 계단식 색상 채움 (하단)
                      if (events.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 30,
                          child: _buildSteppedColors(events),
                        ),
                    ],
                  ),
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
                              border: s.isDate
                                  ? Border.all(color: AppTheme.dateBorderColor, width: 2)
                                  : Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                // 이모지
                                if (s.emoji != null && s.emoji!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Text(
                                      s.emoji!,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  )
                                else
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.workType ?? (s.isDate ? '데이트' : '일정'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: s.isDate
                                              ? AppTheme.dateBorderColor
                                              : AppTheme.textPrimary,
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 18, color: AppTheme.textSecondary),
                                        onPressed: () => _showAddDialog(_selectedDay, s),
                                      ),
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

import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule.dart';
import '../../../shared/models/repeat_pattern.dart';

class ScheduleAddDialog extends StatefulWidget {
  final DateTime? date;
  final Schedule? existingSchedule;

  const ScheduleAddDialog({
    super.key,
    this.date,
    this.existingSchedule,
  });

  @override
  State<ScheduleAddDialog> createState() => _ScheduleAddDialogState();
}

class _ScheduleAddDialogState extends State<ScheduleAddDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late String _title;
  late String? _category;
  late String? _colorHex;
  late String _location;
  late String _note;
  late int? _reminderMinutes;
  late RepeatPattern? _repeatPattern;

  // 반복 요일 (주간 반복용): 1=월 ~ 7=일
  final Set<int> _selectedWeekdays = {};

  static const _colorPalette = <String, Color>{
    '#E53935': Color(0xFFE53935),
    '#E91E63': Color(0xFFE91E63),
    '#9C27B0': Color(0xFF9C27B0),
    '#673AB7': Color(0xFF673AB7),
    '#3F51B5': Color(0xFF3F51B5),
    '#2196F3': Color(0xFF2196F3),
    '#03A9F4': Color(0xFF03A9F4),
    '#00BCD4': Color(0xFF00BCD4),
    '#009688': Color(0xFF009688),
    '#4CAF50': Color(0xFF4CAF50),
    '#8BC34A': Color(0xFF8BC34A),
    '#FFEB3B': Color(0xFFFFEB3B),
    '#FFC107': Color(0xFFFFC107),
    '#FF9800': Color(0xFFFF9800),
    '#FF5722': Color(0xFFFF5722),
    '#795548': Color(0xFF795548),
    '#607D8B': Color(0xFF607D8B),
    '#9E9E9E': Color(0xFF9E9E9E),
    '#212121': Color(0xFF212121),
  };

  final _categories = ['근무', '약속', '여행', '데이트', '기타'];

  // 반복 타입 (표시 이름 → 내부 key 매핑)
  static const _repeatOptions = <String, String?>{
    '없음': null,
    '매일': 'daily',
    '매주': 'weekly',
    '매월': 'monthly',
    '매년': 'yearly',
    '주말마다': '주말',
    '평일마다': '평일',
  };

  String? _selectedRepeatKey; // null = 없음

  // 알림 옵션 (표시 이름 → 분)
  static const _reminderOptions = <String, int?>{
    '없음': null,
    '1분 전': 1,
    '5분 전': 5,
    '10분 전': 10,
    '30분 전': 30,
    '1시간 전': 60,
    '2시간 전': 120,
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = widget.date ?? now;
    _endDate = widget.date ?? now;

    if (widget.existingSchedule != null) {
      final s = widget.existingSchedule!;
      _startTime = s.startTime;
      _endTime = s.endTime;
      _title = s.title ?? s.workType ?? '';
      _category = s.category;
      _colorHex = s.colorHex;
      _location = s.location ?? '';
      _note = s.note ?? '';
      _reminderMinutes = s.reminderMinutes;
      if (s.repeatPattern != null) {
        final rp = RepeatPattern.fromMap(s.repeatPattern!);
        _selectedRepeatKey = rp.type;
        _repeatPattern = rp;
        if (rp.days != null) _selectedWeekdays.addAll(rp.days!);
      } else {
        _repeatPattern = null;
      }
    } else {
      _startTime = null;
      _endTime = null;
      _title = '';
      _category = null;
      _colorHex = null;
      _location = '';
      _note = '';
      _reminderMinutes = null;
      _repeatPattern = null;
    }
  }

  void _onRepeatChanged(String? key) {
    setState(() {
      _selectedRepeatKey = key;
      if (key == null) {
        _repeatPattern = null;
      } else if (key == 'weekly') {
        _repeatPattern = RepeatPattern(
          type: key,
          days: _selectedWeekdays.toList()..sort(),
          startDate: _startDate,
        );
      } else {
        _repeatPattern = RepeatPattern(type: key, startDate: _startDate);
      }
    });
  }

  void _onWeekdayToggle(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
      if (_selectedRepeatKey == 'weekly') {
        _repeatPattern = RepeatPattern(
          type: 'weekly',
          days: _selectedWeekdays.toList()..sort(),
          startDate: _startDate,
        );
      }
    });
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final schedule = widget.existingSchedule != null
        ? widget.existingSchedule!.copyWith(
            title: _title.trim().isEmpty
                ? widget.existingSchedule!.title
                : _title.trim(),
            startTime: _startTime,
            endTime: _endTime,
            category: _category,
            colorHex: _colorHex,
            location: _location.trim().isEmpty ? null : _location.trim(),
            note: _note.trim().isEmpty ? null : _note.trim(),
            reminderMinutes: _reminderMinutes,
            repeatPattern: _repeatPattern?.toMap(),
          )
        : Schedule(
            id: '',
            userId: '',
            coupleId: '',
            date: _startDate,
            startDate: _startDate,
            endDate: _endDate != _startDate ? _endDate : null,
            title: _title.trim(),
            startTime: _startTime,
            endTime: _endTime,
            category: _category,
            colorHex: _colorHex,
            location: _location.trim().isEmpty ? null : _location.trim(),
            note: _note.trim().isEmpty ? null : _note.trim(),
            reminderMinutes: _reminderMinutes,
            repeatPattern: _repeatPattern?.toMap(),
            isAnniversary: false,
          );

    Navigator.pop(context, schedule);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 헤더 ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Text(
                    widget.existingSchedule != null ? '일정 수정' : '일정 추가',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── 내용 ──
            Flexible(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 날짜
                    _buildSectionTitle('날짜'),
                    Row(
                      children: [
                        Expanded(
                          child: _DateButton(
                            label: '시작일',
                            date: _startDate,
                            onChanged: (d) => setState(() => _startDate = d),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateButton(
                            label: '종료일',
                            date: _endDate,
                            onChanged: (d) => setState(() => _endDate = d),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 시간
                    _buildSectionTitle('시간'),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeButton(
                            label: '시작',
                            time: _startTime,
                            onChanged: (v) => setState(() => _startTime = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeButton(
                            label: '종료',
                            time: _endTime,
                            onChanged: (v) => setState(() => _endTime = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 제목
                    _buildSectionTitle('제목 *'),
                    TextFormField(
                      initialValue: _title,
                      decoration: _inputDecoration('일정 제목을 입력하세요'),
                      style: const TextStyle(fontSize: 14),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '제목을 입력해주세요';
                        }
                        return null;
                      },
                      onChanged: (v) => setState(() => _title = v),
                    ),
                    const SizedBox(height: 20),

                    // 종류
                    _buildSectionTitle('종류'),
                    _buildDropdown<String>(
                      value: _category,
                      hint: '종류 선택',
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 20),

                    // 색상
                    _buildSectionTitle('색상'),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _colorPalette.entries.map((e) {
                        final isSelected = _colorHex == e.key;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _colorHex = e.key),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: AppTheme.textPrimary,
                                      width: 2.5)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // 장소
                    _buildSectionTitle('장소'),
                    TextFormField(
                      initialValue: _location,
                      decoration: _inputDecoration('장소 입력',
                          prefixIcon: Icons.location_on_outlined),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (v) => setState(() => _location = v),
                    ),
                    const SizedBox(height: 20),

                    // 메모
                    _buildSectionTitle('메모'),
                    TextFormField(
                      initialValue: _note,
                      maxLines: 3,
                      decoration: _inputDecoration('메모 입력'),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (v) => setState(() => _note = v),
                    ),
                    const SizedBox(height: 20),

                    // 알림
                    _buildSectionTitle('알림'),
                    _buildDropdown<int>(
                      value: _reminderMinutes,
                      hint: '알림 없음',
                      items: _reminderOptions.entries
                          .map((e) => DropdownMenuItem(
                                value: e.value,
                                child: Text(e.key),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _reminderMinutes = v),
                    ),
                    const SizedBox(height: 20),

                    // ── 반복 ──
                    _buildSectionTitle('반복'),
                    _buildDropdown<String>(
                      value: _selectedRepeatKey,
                      hint: '반복 없음',
                      items: _repeatOptions.entries
                          .map((e) => DropdownMenuItem(
                                value: e.value,
                                child: Text(e.key),
                              ))
                          .toList(),
                      onChanged: _onRepeatChanged,
                    ),

                    // 매주 선택 시 요일 체크박스 표시
                    if (_selectedRepeatKey == 'weekly') ...[
                      const SizedBox(height: 12),
                      _buildSectionTitle('반복 요일'),
                      _buildWeekdaySelector(),
                    ],

                    // 반복 종료일
                    if (_selectedRepeatKey != null) ...[
                      const SizedBox(height: 12),
                      _buildSectionTitle('반복 종료일 (선택)'),
                      _DateButton(
                        label: _repeatPattern?.endDate != null
                            ? '${_repeatPattern!.endDate!.year}년 ${_repeatPattern!.endDate!.month}월 ${_repeatPattern!.endDate!.day}일'
                            : '종료일 없음',
                        date: _repeatPattern?.endDate ?? _startDate,
                        onChanged: (d) {
                          setState(() {
                            _repeatPattern = RepeatPattern(
                              type: _selectedRepeatKey!,
                              days:
                                  _selectedWeekdays.isNotEmpty
                                      ? (_selectedWeekdays.toList()..sort())
                                      : null,
                              startDate: _startDate,
                              endDate: d,
                            );
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 버튼
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              '저장',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: const TextStyle(fontSize: 14)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        style: const TextStyle(
            fontSize: 14, color: AppTheme.textPrimary),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = _selectedWeekdays.contains(day);
        return GestureDetector(
          onTap: () => _onWeekdayToggle(day),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : AppTheme.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.border,
              ),
            ),
            child: Center(
              child: Text(
                days[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  InputDecoration _inputDecoration(String hint,
      {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 14),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppTheme.textSecondary)
          : null,
      filled: true,
      fillColor: AppTheme.surface,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

// ───────────────────────────────────────────────────────
// Helper Widgets
// ───────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onChanged;

  const _DateButton({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020, 1, 1),
          lastDate: DateTime(2035, 12, 31),
        );
        if (selected != null && context.mounted) {
          onChanged(selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label.length < 5 ? '$label\n$dateStr' : dateStr,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final void Function(TimeOfDay?) onChanged;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = time != null
        ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
        : '시간 선택';
    return GestureDetector(
      onTap: () async {
        final selected = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
          initialEntryMode: TimePickerEntryMode.input,
        );
        if (selected != null && context.mounted) {
          onChanged(selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const Spacer(),
            Text(
              timeStr,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.access_time,
                size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

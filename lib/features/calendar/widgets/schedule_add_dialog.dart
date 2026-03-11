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

  late DateTime _selectedDate;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late String _title;
  late String? _category;
  late String? _colorHex;
  late String _location;
  late String _note;
  late int? _reminderMinutes;
  late RepeatPattern? _repeatPattern;

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
  };

  final _categories = ['근무', '약속', '여행', '데이트', '기타'];
  final _reminderOptions = ['없음', '1분 전', '5분 전', '10분 전', '30분 전', '1시간 전'];
  final _repeatTypes = ['없음', '매일', '매주', '매월', '매년', '주말', '평일'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();

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
      _repeatPattern = s.repeatPattern != null
          ? RepeatPattern.fromMap(s.repeatPattern!)
          : null;
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

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final schedule = widget.existingSchedule != null
        ? widget.existingSchedule!.copyWith(
            title: _title.trim().isEmpty ? widget.existingSchedule!.title : _title.trim(),
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
            date: _selectedDate,
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
    final dateStr = '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일';
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][_selectedDate.weekday - 1];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              // 내용
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 날짜
                    _buildSectionTitle('날짜'),
                    _buildDateRow(dateStr, weekday),
                    const SizedBox(height: 20),
                    // 시간
                    _buildSectionTitle('시간'),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeSelector(
                            label: '시작',
                            time: _startTime,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _startTime = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeSelector(
                            label: '종료',
                            time: _endTime,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _endTime = v);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 제목
                    _buildSectionTitle('제목 *'),
                    TextFormField(
                      initialValue: _title,
                      decoration: InputDecoration(
                        hintText: '일정 제목을 입력하세요',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: _category,
                        hint: const Text('종류 선택', style: TextStyle(fontSize: 14)),
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: _categories.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _category = v),
                      ),
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
                          onTap: () => setState(() => _colorHex = e.key),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: AppTheme.textPrimary, width: 2.5)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white, size: 18)
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
                      decoration: InputDecoration(
                        hintText: '장소 입력',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (v) => setState(() => _location = v),
                    ),
                    const SizedBox(height: 20),
                    // 메모
                    _buildSectionTitle('메모'),
                    TextFormField(
                      initialValue: _note,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '메모 입력',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (v) => setState(() => _note = v),
                    ),
                    const SizedBox(height: 20),
                    // 알림
                    _buildSectionTitle('알림'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<int>(
                        value: _reminderMinutes,
                        hint: const Text('알림 시간', style: TextStyle(fontSize: 14)),
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: _reminderOptions.asMap().entries.map((e) {
                          final index = e.key;
                          return DropdownMenuItem(
                            value: index == 0 ? null : index * 60,
                            child: Text(e.value, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _reminderMinutes = v),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 반복
                    _buildSectionTitle('반복'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: _repeatPattern?.type,
                        hint: const Text('반복 설정', style: TextStyle(fontSize: 14)),
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: _repeatTypes.map((t) {
                          return DropdownMenuItem(
                            value: t == '없음' ? null : t,
                            child: Text(t, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v == null) {
                            setState(() => _repeatPattern = null);
                          } else {
                            setState(() => _repeatPattern = RepeatPattern(type: v));
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    // 버튼
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('저장'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildDateRow(String dateStr, String weekday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 8),
          Text(
            weekday,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final void Function(TimeOfDay?) onChanged;

  const _TimeSelector({
    super.key,
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
      onTap: () => _selectTime(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const Spacer(),
            Text(
              timeStr,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.access_time, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: time ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (selected != null && context.mounted) {
      onChanged(selected);
    }
  }
}

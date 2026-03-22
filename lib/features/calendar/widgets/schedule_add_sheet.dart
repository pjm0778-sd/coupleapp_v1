import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule.dart';
import '../services/place_search_service.dart';

class ScheduleAddSheet extends StatefulWidget {
  final DateTime initialDate;
  final String myUserId;
  final String? partnerId;
  final String? partnerNickname;
  final String coupleId;
  final Schedule? existingSchedule; // 수정 시 전달

  const ScheduleAddSheet({
    super.key,
    required this.initialDate,
    required this.myUserId,
    required this.coupleId,
    this.partnerId,
    this.partnerNickname,
    this.existingSchedule,
  });

  static Future<Schedule?> show(
    BuildContext context, {
    required DateTime initialDate,
    required String myUserId,
    required String coupleId,
    String? partnerId,
    String? partnerNickname,
    Schedule? existingSchedule,
  }) {
    return showModalBottomSheet<Schedule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ScheduleAddSheet(
          initialDate: initialDate,
          myUserId: myUserId,
          coupleId: coupleId,
          partnerId: partnerId,
          partnerNickname: partnerNickname,
          existingSchedule: existingSchedule,
        ),
      ),
    );
  }

  @override
  State<ScheduleAddSheet> createState() => _ScheduleAddSheetState();
}

class _ScheduleAddSheetState extends State<ScheduleAddSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  late String _ownerType; // 'me' | 'partner' | 'couple'
  late bool _isAllDay;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late String? _colorHex;
  late String? _category;
  late String _location;
  late String _note;
  late double? _latitude;
  late double? _longitude;

  bool _isSaving = false;
  bool _isSaved = false;

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

  static const _categories = ['출근', '외출', '여행', '데이트', '기타'];

  @override
  void initState() {
    super.initState();
    final s = widget.existingSchedule;
    if (s != null) {
      _titleController.text = s.title ?? s.workType ?? '';
      _ownerType = s.ownerType;
      _isAllDay = s.startTime == null && s.endTime == null;
      _startDate = s.startDate ?? s.date;
      _endDate = s.endDate ?? s.startDate ?? s.date;
      _startTime = s.startTime;
      _endTime = s.endTime;
      _colorHex = s.colorHex;
      _category = s.category;
      _location = s.location ?? '';
      _note = s.note ?? '';
      _latitude = s.latitude;
      _longitude = s.longitude;
    } else {
      _ownerType = 'me';
      _isAllDay = true;
      _startDate = widget.initialDate;
      _endDate = widget.initialDate;
      _startTime = null;
      _endTime = null;
      _colorHex = null;
      _category = null;
      _location = '';
      _note = '';
      _latitude = null;
      _longitude = null;
    }
    _locationController.text = _location;
    _noteController.text = _note;
  }

  Future<void> _openPlaceSearch() async {
    final result = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PlaceSearchSheet(),
    );
    if (result != null && mounted) {
      setState(() {
        _location = result.name;
        _latitude = result.lat;
        _longitude = result.lng;
        _locationController.text = result.name;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _targetUserId {
    if (_ownerType == 'partner') return widget.partnerId ?? widget.myUserId;
    return widget.myUserId;
  }

  Future<void> _onSave() async {
    final title = _titleController.text.trim();
    _location = _locationController.text.trim();
    _note = _noteController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    // Phase 1: show saving spinner
    setState(() {
      _isSaving = true;
      _isSaved = false;
    });
    await Future.delayed(const Duration(milliseconds: 100));

    // Phase 2: show saved checkmark
    if (mounted) {
      setState(() => _isSaved = true);
    }
    await Future.delayed(const Duration(milliseconds: 500));

    final s = widget.existingSchedule;
    final schedule = s != null
        ? Schedule(
            id: s.id,
            userId: s.userId,
            coupleId: s.coupleId,
            date: _startDate,
            startDate: _startDate,
            endDate: _endDate != _startDate ? _endDate : null,
            title: title,
            startTime: _isAllDay ? null : _startTime,
            endTime: _isAllDay ? null : _endTime,
            colorHex: _colorHex,
            category: _category,
            location: _location.trim().isEmpty ? null : _location.trim(),
            note: _note.trim().isEmpty ? null : _note.trim(),
            ownerType: _ownerType,
            isDate: _ownerType == 'couple',
            isAnniversary: s.isAnniversary,
            reminderMinutes: s.reminderMinutes,
            repeatPattern: s.repeatPattern,
            workType: s.workType,
            emoji: s.emoji,
            repeatGroupId: s.repeatGroupId,
            isOcr: s.isOcr,
            isGoogleCalendar: s.isGoogleCalendar,
            latitude: _latitude,
            longitude: _longitude,
          )
        : Schedule(
            id: '',
            userId: _targetUserId,
            coupleId: widget.coupleId,
            date: _startDate,
            startDate: _startDate,
            endDate: _endDate != _startDate ? _endDate : null,
            title: title,
            startTime: _isAllDay ? null : _startTime,
            endTime: _isAllDay ? null : _endTime,
            colorHex: _colorHex,
            category: _category,
            location: _location.trim().isEmpty ? null : _location.trim(),
            note: _note.trim().isEmpty ? null : _note.trim(),
            ownerType: _ownerType,
            isDate: _ownerType == 'couple',
            isAnniversary: false,
            latitude: _latitude,
            longitude: _longitude,
          );

    if (mounted) Navigator.pop(context, schedule);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked.isBefore(_startDate) ? _startDate : picked;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 10, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final partnerLabel = widget.partnerNickname ?? '파트너';
    final isEdit = widget.existingSchedule != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 드래그 핸들 ──
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── 헤더 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                Text(
                  isEdit ? '일정 수정' : '일정 추가',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── 내용 (스크롤) ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 제목
                  TextField(
                    controller: _titleController,
                    autofocus: !isEdit,
                    decoration: _inputDecoration('일정 제목을 입력하세요 *'),
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),

                  // 2. 누구 일정?
                  _sectionLabel('누구 일정?'),
                  const SizedBox(height: 8),
                  _OwnerSelector(
                    value: _ownerType,
                    partnerLabel: partnerLabel,
                    onChanged: (v) => setState(() => _ownerType = v),
                  ),
                  if (_ownerType == 'partner') ...[
                    const SizedBox(height: 6),
                    Text(
                      '$partnerLabel 대신 등록하는 일정이에요',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // 3. 하루종일
                  Row(
                    children: [
                      _sectionLabel('하루종일'),
                      const Spacer(),
                      Switch(
                        value: _isAllDay,
                        activeThumbColor: AppTheme.accent,
                        onChanged: (v) => setState(() => _isAllDay = v),
                      ),
                    ],
                  ),

                  // 4. 날짜 + 시간 (하루종일 OFF 시 시간 표시)
                  const SizedBox(height: 8),
                  _DateTimeRow(
                    label: '시작',
                    date: _startDate,
                    time: _isAllDay ? null : _startTime,
                    showTime: !_isAllDay,
                    onDateTap: () => _pickDate(isStart: true),
                    onTimeTap: () => _pickTime(isStart: true),
                  ),
                  const SizedBox(height: 8),
                  _DateTimeRow(
                    label: '종료',
                    date: _endDate,
                    time: _isAllDay ? null : _endTime,
                    showTime: !_isAllDay,
                    onDateTap: () => _pickDate(isStart: false),
                    onTimeTap: () => _pickTime(isStart: false),
                  ),
                  const SizedBox(height: 16),

                  // 5. 색상
                  _sectionLabel('색상'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorPalette.entries.map((e) {
                      final selected = _colorHex == e.key;
                      return GestureDetector(
                        onTap: () => setState(() => _colorHex = e.key),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.value,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: AppTheme.accent,
                                    width: 2.5,
                                  )
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 6. 종류
                  _sectionLabel('종류'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((c) {
                      final selected = _category == c;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _category = selected ? null : c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.accentLight
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.accent
                                  : AppTheme.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 13,
                              color: selected
                                  ? AppTheme.accent
                                  : AppTheme.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 7. 장소
                  _sectionLabel('장소 (선택)'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openPlaceSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: AppTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _location.isEmpty ? '장소 검색' : _location,
                              style: TextStyle(
                                fontSize: 14,
                                color: _location.isEmpty
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_location.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() {
                                _location = '';
                                _latitude = null;
                                _longitude = null;
                                _locationController.clear();
                              }),
                              child: const Icon(Icons.close,
                                  size: 16, color: AppTheme.textSecondary),
                            )
                          else
                            const Icon(Icons.search,
                                size: 18, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 8. 메모
                  _sectionLabel('메모 (선택)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    onChanged: (v) => _note = v,
                    maxLines: 3,
                    decoration: _inputDecoration('메모를 입력하세요'),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // 저장 버튼
                  AnimatedScale(
                    scale: _isSaving && !_isSaved ? 0.97 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSaved
                              ? const Color(0xFF4CAF50)
                              : AppTheme.accent,
                          foregroundColor: AppTheme.primary,
                          disabledBackgroundColor: _isSaved
                              ? const Color(0xFF4CAF50)
                              : AppTheme.accent,
                          disabledForegroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: _isSaved
                              ? Row(
                                  key: const ValueKey('saved'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.check,
                                        size: 20, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      '저장됨!',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : _isSaving
                                  ? Row(
                                      key: const ValueKey('saving'),
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          '저장 중...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      key: const ValueKey('normal'),
                                      isEdit ? '수정 완료' : '저장',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppTheme.textSecondary)
          : null,
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

// ────────────────────────────────────────────────────
// 소유자 선택 버튼 그룹
// ────────────────────────────────────────────────────
class _OwnerSelector extends StatelessWidget {
  final String value;
  final String partnerLabel;
  final void Function(String) onChanged;

  const _OwnerSelector({
    required this.value,
    required this.partnerLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OwnerBtn(label: '나', value: 'me', selected: value == 'me', onTap: onChanged),
        const SizedBox(width: 8),
        _OwnerBtn(
          label: partnerLabel,
          value: 'partner',
          selected: value == 'partner',
          onTap: onChanged,
          color: const Color(0xFF9C6FE4),
        ),
        const SizedBox(width: 8),
        _OwnerBtn(
          label: '우리',
          value: 'couple',
          selected: value == 'couple',
          onTap: onChanged,
          color: const Color(0xFFFF6B9D),
        ),
      ],
    );
  }
}

class _OwnerBtn extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String) onTap;
  final Color color;

  const _OwnerBtn({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFF4F86F7),
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: selected ? color : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppTheme.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// 날짜+시간 한 행
// ────────────────────────────────────────────────────
class _DateTimeRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final TimeOfDay? time;
  final bool showTime;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  const _DateTimeRow({
    required this.label,
    required this.date,
    required this.time,
    required this.showTime,
    required this.onDateTap,
    required this.onTimeTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    final timeStr = time != null
        ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
        : '시간 설정';

    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: onDateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(dateStr,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),
        ),
        if (showTime) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTimeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(timeStr,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────
// 장소 검색 바텀시트
// ────────────────────────────────────────────────────
class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet();

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _service = PlaceSearchService();
  final _ctrl = TextEditingController();
  List<PlaceResult> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _service.search(q);
      if (mounted) setState(() { _results = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '검색 실패: $e'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '장소명 또는 주소를 입력하세요',
                hintStyle: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: AppTheme.textSecondary),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _results = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
              },
              onSubmitted: _search,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // 결과
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppTheme.textSecondary)))
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _ctrl.text.isEmpty
                                  ? '검색어를 입력하세요'
                                  : '검색 결과가 없어요',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 56),
                            itemBuilder: (ctx, i) {
                              final p = _results[i];
                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: AppTheme.primary),
                                ),
                                title: Text(p.name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(p.address,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary)),
                                onTap: () => Navigator.pop(ctx, p),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

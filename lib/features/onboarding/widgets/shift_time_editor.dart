import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/wheel_time_picker.dart';
import '../../profile/models/shift_time.dart';

class ShiftTimeEditor extends StatefulWidget {
  final List<ShiftTime> shiftTimes;
  final ValueChanged<List<ShiftTime>> onChanged;
  final bool enableTypeEdit;
  final bool enableAddRemove;

  const ShiftTimeEditor({
    super.key,
    required this.shiftTimes,
    required this.onChanged,
    this.enableTypeEdit = false,
    this.enableAddRemove = false,
  });

  @override
  State<ShiftTimeEditor> createState() => _ShiftTimeEditorState();
}

class _ShiftTimeEditorState extends State<ShiftTimeEditor> {
  static const _presetShiftColors = [
    '#4CAF50',
    '#2196F3',
    '#FF9800',
    '#7E57C2',
    '#E91E63',
    '#F44336',
    '#00BCD4',
    '#607D8B',
    '#BDBDBD',
  ];

  late List<ShiftTime> _times;

  Color _hexToColor(String? hex) {
    final raw = (hex ?? '').replaceAll('#', '').trim();
    if (raw.length != 6) return AppTheme.primary;
    try {
      return Color(int.parse('FF$raw', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  String _defaultColorHexForCode(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized == 'd' || normalized == 'day') return '#4CAF50';
    if (normalized == 'e') return '#2196F3';
    if (normalized == 'm') return '#FF9800';
    if (normalized == 'n' || normalized == 'night') return '#7E57C2';
    if (normalized == 'office') return '#43A047';
    if (normalized == 'work') return '#00897B';
    return '#4CAF50';
  }

  String _resolvedColorHex(ShiftTime shift) {
    final raw = shift.colorHex?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw.startsWith('#') ? raw : '#$raw';
    }
    return _defaultColorHexForCode(shift.shiftType);
  }

  @override
  void initState() {
    super.initState();
    _times = List<ShiftTime>.from(widget.shiftTimes);
  }

  @override
  void didUpdateWidget(ShiftTimeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 근무 유형 변경 등으로 외부 shiftTimes가 바뀌면 내부 상태 동기화
    final old = oldWidget.shiftTimes;
    final next = widget.shiftTimes;
    final changed = old.length != next.length ||
        Iterable.generate(old.length).any((i) => old[i] != next[i]);
    if (changed) {
      setState(() => _times = List<ShiftTime>.from(next));
    }
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final current = _times[index];
    final initial = isStart ? current.startTime : current.endTime;
    final picked = await showWheelTimePicker(
      context: context,
      initialTime: initial,
      title: isStart ? '시작 시간 선택' : '종료 시간 선택',
    );
    if (picked == null) return;
    setState(() {
      _times[index] = isStart
          ? current.copyWith(
              startHour: picked.hour,
              startMinute: picked.minute,
            )
          : current.copyWith(
              endHour: picked.hour,
              endMinute: picked.minute,
            );
    });
    widget.onChanged(List<ShiftTime>.from(_times));
  }

  Future<void> _editShiftType(int index) async {
    final current = _times[index];
    final controller = TextEditingController(text: current.shiftType);
    String selectedColorHex = _resolvedColorHex(current);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('일정 코드 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: '예: D, E, M, N, F',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '일정 색상',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetShiftColors.map((hex) {
                  final selected = hex.toUpperCase() == selectedColorHex.toUpperCase();
                  final color = _hexToColor(hex);
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColorHex = hex),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black87 : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'code': controller.text.trim(),
                'color': selectedColorHex,
              }),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final next = (result['code'] ?? '').toUpperCase();
    final colorHex = result['color'];
    if (next.isEmpty) return;

    final duplicated = _times.asMap().entries.any(
      (e) =>
          e.key != index &&
          e.value.shiftType.trim().toUpperCase() == next,
    );
    if (duplicated) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 존재하는 일정 코드입니다')));
      return;
    }

    setState(() {
      _times[index] = current.copyWith(
        shiftType: next,
        label: next,
        colorHex: colorHex,
      );
    });
    widget.onChanged(List<ShiftTime>.from(_times));
  }

  Future<void> _addShiftType() async {
    final codeController = TextEditingController();

    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('추가'),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '일정 코드',
            hintText: '예: F',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, codeController.text.trim().toUpperCase()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (added == null) return;
    final code = added;

    if (code.isEmpty) return;
    final duplicated = _times.any(
      (t) => t.shiftType.trim().toUpperCase() == code,
    );
    if (duplicated) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 존재하는 일정 코드입니다')));
      return;
    }

    setState(() {
      _times.add(
        ShiftTime(
          shiftType: code,
          label: code,
          colorHex: '#4CAF50',
          startHour: 9,
          startMinute: 0,
          endHour: 18,
          endMinute: 0,
          isNextDay: false,
        ),
      );
    });
    widget.onChanged(List<ShiftTime>.from(_times));
  }

  void _removeShiftType(int index) {
    if (_times.length <= 1) return;
    setState(() {
      _times.removeAt(index);
    });
    widget.onChanged(List<ShiftTime>.from(_times));
  }

  void _toggleAllDay(int index) {
    final current = _times[index];
    setState(() {
      _times[index] = current.copyWith(
        isAllDay: !current.isAllDay,
        isNextDay: !current.isAllDay ? false : current.isNextDay,
      );
    });
    widget.onChanged(List<ShiftTime>.from(_times));
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(_times.length, (i) {
          final s = _times[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: widget.enableTypeEdit ? () => _editShiftType(i) : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _hexToColor(_resolvedColorHex(s)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.shiftType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _toggleAllDay(i),
                  child: _modeChip('종일', active: s.isAllDay),
                ),
                if (!s.isAllDay) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _pickTime(i, true),
                    child: _timeChip(_fmt(s.startHour, s.startMinute)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('~', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  GestureDetector(
                    onTap: () => _pickTime(i, false),
                    child: _timeChip(
                      _fmt(s.endHour, s.endMinute) + (s.isNextDay ? '+1' : ''),
                    ),
                  ),
                ],
                if (widget.enableAddRemove) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _removeShiftType(i),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.textTertiary,
                    ),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    splashRadius: 18,
                  ),
                ],
              ],
            ),
          );
        }),
        if (widget.enableAddRemove)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _addShiftType,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('추가'),
            ),
          ),
      ],
    );
  }

  Widget _timeChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.primary,
      ),
    ),
  );

  Widget _modeChip(String label, {required bool active}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: active
          ? AppTheme.primary.withValues(alpha: 0.14)
          : AppTheme.textTertiary.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: active ? AppTheme.primary : AppTheme.border,
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: active ? AppTheme.primary : AppTheme.textSecondary,
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../profile/models/shift_time.dart';

class ShiftTimeEditor extends StatefulWidget {
  final List<ShiftTime> shiftTimes;
  final ValueChanged<List<ShiftTime>> onChanged;

  const ShiftTimeEditor({
    super.key,
    required this.shiftTimes,
    required this.onChanged,
  });

  @override
  State<ShiftTimeEditor> createState() => _ShiftTimeEditorState();
}

class _ShiftTimeEditorState extends State<ShiftTimeEditor> {
  late List<ShiftTime> _times;

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
    final picked = await showTimePicker(context: context, initialTime: initial);
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
    widget.onChanged(_times);
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_times.length, (i) {
        final s = _times[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.shiftType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                s.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
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
          ),
        );
      }),
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
}

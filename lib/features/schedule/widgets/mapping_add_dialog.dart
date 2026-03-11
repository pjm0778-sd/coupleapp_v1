import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/color_mapping.dart';

class MappingAddDialog extends StatefulWidget {
  final ColorMapping? existingMapping;

  const MappingAddDialog({super.key, this.existingMapping});

  @override
  State<MappingAddDialog> createState() => _MappingAddDialogState();
}

class _MappingAddDialogState extends State<MappingAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _colorKeys = <Color, String>{
    const Color(0xFFE53935): '#E53935',
    const Color(0xFFE91E63): '#E91E63',
    const Color(0xFF9C27B0): '#9C27B0',
    const Color(0xFF673AB7): '#673AB7',
    const Color(0xFF3F51B5): '#3F51B5',
    const Color(0xFF2196F3): '#2196F3',
    const Color(0xFF03A9F4): '#03A9F4',
    const Color(0xFF00BCD4): '#00BCD4',
    const Color(0xFF009688): '#009688',
    const Color(0xFF4CAF50): '#4CAF50',
    const Color(0xFF8BC34A): '#8BC34A',
    const Color(0xFFFFEB3B): '#FFEB3B',
    const Color(0xFFFFC107): '#FFC107',
    const Color(0xFFFF9800): '#FF9800',
    const Color(0xFFFF5722): '#FF5722',
    const Color(0xFF795548): '#795548',
    const Color(0xFF607D8B): '#607D8B',
    const Color(0xFF9E9E9E): '#9E9E9E',
    const Color(0xFF212121): '#212121',
  };

  late Color _selectedColor;
  final _titleController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    if (widget.existingMapping != null) {
      final m = widget.existingMapping!;
      _selectedColor = _hexToColor(m.colorHex);
      _titleController.text = m.title;
      _startTime = m.startTime;
      _endTime = m.endTime;
    } else {
      _selectedColor = _colorKeys.keys.first;
      _startTime = TimeOfDay.now();
      _endTime = const TimeOfDay(hour: 18, minute: 0);
    }
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return _colorKeys.keys.first;
    }
  }

  bool get _isNightShift =>
      _startTime != null && _endTime != null && _startTime!.hour > _endTime!.hour;

  void _onSave() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }

    final mapping = ColorMapping(
      id: widget.existingMapping?.id ?? '',
      userId: widget.existingMapping?.userId ?? '',
      colorHex: _colorKeys[_selectedColor]!,
      title: title,
      startTime: _startTime,
      endTime: _endTime,
    );

    Navigator.pop(context, mapping);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart
        ? (_startTime ?? TimeOfDay.now())
        : (_endTime ?? const TimeOfDay(hour: 18, minute: 0));

    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (selected != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = selected;
          // 야간근무 자동감지: 시작이 18시 이후면 종료를 다음날 09시로
          if (selected.hour >= 18 && selected.hour < 23) {
            _endTime = const TimeOfDay(hour: 9, minute: 0);
          }
        } else {
          _endTime = selected;
        }
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingMapping != null ? '매핑 수정' : '새 매핑 추가',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 색상 선택
                const Text(
                  '색상 *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colorKeys.entries.map((entry) {
                    final color = entry.key;
                    final isSelected = color == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppTheme.textPrimary, width: 3)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 22)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                // 제목
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: '제목',
                    hintText: '예: 주간근무',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  style: const TextStyle(fontSize: 14),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '제목을 입력해주세요';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // 시간
                const Text(
                  '시간',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '시작',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(_startTime),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '종료',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(_endTime),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isNightShift)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '야간근무로 인식됩니다',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                const SizedBox(height: 30),
                // 버튼
                Row(
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
                        child: Text(widget.existingMapping != null ? '수정' : '저장'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/color_mapping.dart';

class MappingAddDialog extends StatefulWidget {
  const MappingAddDialog({super.key});

  @override
  State<MappingAddDialog> createState() => _MappingAddDialogState();
}

class _MappingAddDialogState extends State<MappingAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _colorKeys = <Color, String>{
    const Color(0xFFFF0000): '#FF0000', // 빨강
    const Color(0xFFFF5200): '#FF5200', // 주황
    const Color(0xFF2196F3): '#2196F3', // 파랑
    const Color(0xFF4CAF50): '#4CAF50', // 녹색
    const Color(0xFF9C27B0): '#9C27B0', // 보라
    const Color(0xFFFF9800): '#FF9800', // 주황
  };

  late Color _selectedColor;
  final _titleController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _selectedColor = _colorKeys.keys.first;
    _startTime = TimeOfDay.now();
    _endTime = const TimeOfDay(hour: 18, minute: 0);
  }

  bool get _isNightShift =>
      _startTime != null && _endTime != null && _startTime!.hour > _endTime!.hour;

  void _onSave() {
    // Form 유효성 검사
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
      id: '',
      userId: '',
      colorHex: _colorKeys[_selectedColor]!,
      title: title,
      startTime: _startTime,
      endTime: _endTime,
    );

    Navigator.pop(context, mapping);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _startTime != null && _endTime != null
        ? '${_formatTime(_startTime)} ~ ${_formatTime(_endTime)}'
        : '시간 선택';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '새 매핑 추가',
                    style: TextStyle(
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
              // 색상 선택 (8개)
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
                spacing: 12,
                runSpacing: 12,
                children: _colorKeys.entries.map((entry) {
                  final color = entry.key;
                  final isSelected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppTheme.textPrimary, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
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
                  hintText: '예: 정비공',
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
                  if (v == null || v.trim().isEmpty) {
                    return '제목을 입력해주세요';
                  }
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
              GestureDetector(
                onTap: () => _selectStartTime(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isNightShift)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    '야간근무로 인식됩니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
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
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (selected != null && context.mounted) {
      setState(() => _startTime = selected);
      // 야간근무라면 종료시간을 자동 설정
      if (selected!.hour >= 18 && selected!.hour < 23) {
        setState(() => _endTime = const TimeOfDay(hour: 9, minute: 0));
      }
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

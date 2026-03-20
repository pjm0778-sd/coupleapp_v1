import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models/schedule.dart';
import '../../calendar/services/schedule_service.dart';

class OcrReviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> schedules;
  final int ocrYear;
  final int ocrMonth;
  final String userId;
  final String? coupleId;
  final bool isGoogleCalendar;

  const OcrReviewScreen({
    super.key,
    required this.schedules,
    required this.ocrYear,
    required this.ocrMonth,
    required this.userId,
    required this.coupleId,
    this.isGoogleCalendar = false,
  });

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  late List<Map<String, dynamic>> _schedules;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 각 항목에 고유 키 부여 (Dismissible 안정성)
    int i = 0;
    _schedules = widget.schedules.map((s) {
      final copy = Map<String, dynamic>.from(s);
      copy['_key'] = '${i++}_${s['start_date']}_${s['work_type']}';
      return copy;
    }).toList();
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  void _deleteItem(String key) {
    setState(() => _schedules.removeWhere((s) => s['_key'] == key));
  }

  Future<void> _editItem(int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _OcrItemEditDialog(item: _schedules[index]),
    );
    if (result != null) {
      setState(() => _schedules[index] = result);
    }
  }

  String? _detectCategory(String? workType) {
    if (workType == null || workType.isEmpty) return '출근';
    final t = workType.toLowerCase();
    if (t.contains('여행') || t.contains('출장') || t.contains('trip') ||
        t.contains('travel')) {
      return '여행';
    }
    if (t.contains('데이트') || t.contains('date')) return '데이트';
    if (t.contains('약속') || t.contains('미팅') || t.contains('회의') ||
        t.contains('meeting')) {
      return '약속';
    }
    return '출근';
  }

  Future<void> _submit() async {
    if (widget.coupleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('커플 연결이 필요합니다')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ScheduleService();
      int saved = 0;

      for (final s in _schedules) {
        final startDateStr = s['start_date'] as String?;
        if (startDateStr == null) continue;

        final endDateStr = s['end_date'] as String?;
        final workType = s['work_type'] as String?;
        final colorHex = s['color_hex'] as String?;
        final startTimeStr = s['start_time'] as String?;
        final endTimeStr = s['end_time'] as String?;

        TimeOfDay? startTime, endTime;
        if (startTimeStr != null && startTimeStr.contains(':')) {
          final parts = startTimeStr.split(':');
          startTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        if (endTimeStr != null && endTimeStr.contains(':')) {
          final parts = endTimeStr.split(':');
          endTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }

        final startDate = DateTime.parse(startDateStr);
        final endDate =
            endDateStr != null ? DateTime.parse(endDateStr) : startDate;

        final schedule = Schedule(
          id: '',
          userId: widget.userId,
          coupleId: widget.coupleId,
          date: startDate,
          startDate: startDate,
          endDate: endDate,
          title: workType,
          workType: workType,
          colorHex: colorHex,
          startTime: startTime,
          endTime: endTime,
          isAnniversary: false,
          isOcr: !widget.isGoogleCalendar,
          isGoogleCalendar: widget.isGoogleCalendar,
          category: s['category'] as String? ?? _detectCategory(workType),
        );

        await service.addSchedule(schedule);
        saved++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$saved개의 일정이 저장되었습니다')),
        );
        Navigator.pop(context, saved);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('일정 저장 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('분석 결과 — ${widget.ocrYear}년 ${widget.ocrMonth}월'),
      ),
      body: _schedules.isEmpty
          ? const Center(
              child: Text(
                '저장할 일정이 없습니다',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${_schedules.length}건 감지됨',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '탭: 수정  |  좌로 스와이프: 삭제',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _schedules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final s = _schedules[index];
                      final color = _hexToColor(
                        s['color_hex'] as String? ?? '#000000',
                      );
                      final key = s['_key'] as String;

                      return Dismissible(
                        key: ValueKey(key),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteItem(key),
                        child: GestureDetector(
                          onTap: () => _editItem(index),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['work_type'] as String? ?? '일정',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s['start_date'] == s['end_date']
                                            ? s['start_date'] as String? ?? ''
                                            : '${s['start_date']} ~ ${s['end_date']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      if (s['start_time'] != null)
                                        Text(
                                          s['end_time'] != null
                                              ? '${s['start_time']} ~ ${s['end_time']}'
                                              : s['start_time'] as String,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            _schedules.isEmpty || _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '${_schedules.length}개 일정 달력에 추가',
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
    );
  }
}

class _OcrItemEditDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  const _OcrItemEditDialog({required this.item});

  @override
  State<_OcrItemEditDialog> createState() => _OcrItemEditDialogState();
}

class _OcrItemEditDialogState extends State<_OcrItemEditDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _startDateCtrl;
  late TextEditingController _endDateCtrl;
  late TextEditingController _startTimeCtrl;
  late TextEditingController _endTimeCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.item['work_type'] as String? ?? '',
    );
    _startDateCtrl = TextEditingController(
      text: widget.item['start_date'] as String? ?? '',
    );
    _endDateCtrl = TextEditingController(
      text: widget.item['end_date'] as String? ?? '',
    );
    _startTimeCtrl = TextEditingController(
      text: widget.item['start_time'] as String? ?? '',
    );
    _endTimeCtrl = TextEditingController(
      text: widget.item['end_time'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('일정 수정'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: '일정명',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startDateCtrl,
              decoration: const InputDecoration(
                labelText: '시작일 (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endDateCtrl,
              decoration: const InputDecoration(
                labelText: '종료일 (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startTimeCtrl,
              decoration: const InputDecoration(
                labelText: '시작시간 (HH:mm, 선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endTimeCtrl,
              decoration: const InputDecoration(
                labelText: '종료시간 (HH:mm, 선택)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final updated = Map<String, dynamic>.from(widget.item);
            updated['work_type'] = _titleCtrl.text.trim();
            updated['start_date'] = _startDateCtrl.text.trim();
            final endDate = _endDateCtrl.text.trim();
            updated['end_date'] =
                endDate.isEmpty ? _startDateCtrl.text.trim() : endDate;
            final st = _startTimeCtrl.text.trim();
            final et = _endTimeCtrl.text.trim();
            if (st.isNotEmpty) updated['start_time'] = st;
            if (et.isNotEmpty) updated['end_time'] = et;
            Navigator.pop(context, updated);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

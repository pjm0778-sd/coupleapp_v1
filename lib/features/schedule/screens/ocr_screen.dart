import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/color_mapping.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  XFile? _image;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _extractedSchedules = [];
  List<ColorMapping> _colorMappings = [];
  String? _coupleId;

  int _targetYear = DateTime.now().year;
  int _targetMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _loadMappings();
  }

  Future<void> _loadMappings() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .single();
    _coupleId = profile['couple_id'] as String?;

    final data = await supabase
        .from('color_mappings')
        .select()
        .eq('user_id', userId);
    setState(() {
      _colorMappings =
          (data as List).map((e) => ColorMapping.fromMap(e)).toList();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      setState(() {
        _image = file;
        _extractedSchedules = [];
      });
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;

    // 매핑을 분석 시작 시 항상 최신으로 재로드
    await _loadMappings();

    if (_colorMappings.isEmpty) {
      _showSnack('설정에서 색상 매핑을 먼저 추가해주세요');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // 이미지 크기 축소 (최대 1024px, 품질 70%)
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _image!.mimeType ?? 'image/jpeg';

      // 이미지가 너무 크면 경고
      final sizeKB = bytes.length / 1024;
      if (sizeKB > 4096) {
        _showSnack('이미지가 너무 큽니다 (${sizeKB.toStringAsFixed(0)}KB). 더 작은 이미지를 사용해주세요.');
        return;
      }

      final result = await supabase.functions.invoke(
        'ocr-schedule',
        body: {
          'imageBase64': base64Image,
          'imageMediaType': mimeType,
          'colorMappings': _colorMappings
              .map((m) => {
                'color_hex': m.colorHex,
                'work_type': m.workType,
                'start_time': m.startTime != null ? '${m.startTime!.hour.toString().padLeft(2, '0')}:${m.startTime!.minute.toString().padLeft(2, '0')}' : null,
                'end_time': m.endTime != null ? '${m.endTime!.hour.toString().padLeft(2, '0')}:${m.endTime!.minute.toString().padLeft(2, '0')}' : null,
              })
              .toList(),
          'targetYear': _targetYear,
          'targetMonth': _targetMonth,
        },
      );

      // Edge Function 에러 확인
      final data = result.data as Map<String, dynamic>?;
      if (data == null) {
        _showSnack('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.');
        return;
      }
      if (data.containsKey('error')) {
        _showSnack('분석 오류: ${data['error']}');
        return;
      }

      final schedules = data['schedules'] as List?;
      final detectedYear = data['year'] as int?;
      final detectedMonth = data['month'] as int?;

      if (schedules == null || schedules.isEmpty) {
        _showSnack('일정을 추출하지 못했어요.\n색상 매핑이 이미지 색상과 맞는지 확인해주세요.');
        return;
      }

      setState(() {
        _extractedSchedules = schedules.cast<Map<String, dynamic>>();
        if (detectedYear != null) _targetYear = detectedYear;
        if (detectedMonth != null) _targetMonth = detectedMonth;
      });

      if (detectedYear != null || detectedMonth != null) {
        _showSnack('AI가 ${detectedYear ?? _targetYear}년 ${detectedMonth ?? _targetMonth}월 일정을 찾았습니다.');
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('FunctionException')) {
        _showSnack('Edge Function 오류입니다. Supabase 대시보드 → Logs → Edge Functions 에서 확인해주세요.');
      } else {
        _showSnack('오류: $msg');
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveSchedules() async {
    if (_extractedSchedules.isEmpty || _coupleId == null) return;
    setState(() => _isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final rows = _extractedSchedules.map((s) {
            String? startTimeStr = s['start_time'];
            String? endTimeStr = s['end_time'];
            return {
              'user_id': userId,
              'couple_id': _coupleId,
              'date': s['date'],
              'work_type': s['work_type'],
              'color_hex': s['color_hex'],
              'start_time': startTimeStr,
              'end_time': endTimeStr,
              'category': '근무', // 자동 추출 일정은 카테고리 근무
            };
          }).toList();

      await supabase.from('schedules').insert(rows);
      _showSnack('${rows.length}개 일정이 저장됐어요!');
      setState(() {
        _image = null;
        _extractedSchedules = [];
      });
    } catch (e) {
      _showSnack('저장 중 오류가 발생했습니다');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _removeSchedule(int index) {
    setState(() => _extractedSchedules.removeAt(index));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Color _hexToColor(String? hex) {
    if (hex == null) return AppTheme.primary;
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('스케줄 이미지 분석')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withAlpha(40)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '마이듀티 등 근무표 캡처 이미지를 업로드하면\nAI가 색상을 분석해 자동으로 일정을 추출합니다',
                      style: TextStyle(fontSize: 13, color: AppTheme.primary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 년월 선택
            const Text('스케줄 년/월',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMonthBtn(Icons.chevron_left, () {
                  setState(() {
                    if (_targetMonth == 1) {
                      _targetMonth = 12;
                      _targetYear--;
                    } else {
                      _targetMonth--;
                    }
                  });
                }),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_targetYear년 $_targetMonth월',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                _buildMonthBtn(Icons.chevron_right, () {
                  setState(() {
                    if (_targetMonth == 12) {
                      _targetMonth = 1;
                      _targetYear++;
                    } else {
                      _targetMonth++;
                    }
                  });
                }),
              ],
            ),
            const SizedBox(height: 24),

            // 이미지 업로드
            const Text('스케줄 이미지',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(
                    color: _image != null ? AppTheme.primary : AppTheme.border,
                    width: _image != null ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _image == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 40, color: AppTheme.textSecondary),
                          SizedBox(height: 10),
                          Text('이미지를 선택하세요',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 14)),
                        ],
                      )
                    : FutureBuilder<String>(
                        future: _image!.path.startsWith('blob')
                            ? Future.value(_image!.path)
                            : Future.value(_image!.path),
                        builder: (ctx2, snap2) => ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            _image!.path,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx3, err, stack) => const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: AppTheme.primary, size: 36),
                                  SizedBox(height: 8),
                                  Text('이미지 선택 완료',
                                      style: TextStyle(color: AppTheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // 분석 버튼
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed:
                    (_image == null || _isAnalyzing) ? null : _analyze,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _isAnalyzing ? 'AI 분석 중...' : 'AI로 일정 분석',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // 추출 결과
            if (_extractedSchedules.isNotEmpty) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    '추출된 일정 (${_extractedSchedules.length}개)',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '스와이프로 제거',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: _extractedSchedules
                      .asMap()
                      .entries
                      .map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return Dismissible(
                      key: Key('$i-${s['date']}'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _removeSchedule(i),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(30),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _hexToColor(s['color_hex'] as String?),
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              s['date'] as String? ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _hexToColor(s['color_hex'] as String?)
                                    .withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s['work_type'] as String? ?? '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _hexToColor(s['color_hex'] as String?),
                                ),
                              ),
                            ),
                          ),
                          if (i < _extractedSchedules.length - 1)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _saveSchedules,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(
                    _isSaving
                        ? '저장 중...'
                        : '${_extractedSchedules.length}개 일정 저장',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }
}

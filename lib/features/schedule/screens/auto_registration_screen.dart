import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/color_mapping.dart';
import '../../../shared/models/schedule.dart';
import '../../calendar/services/schedule_service.dart';
import '../widgets/mapping_add_dialog.dart';
import '../widgets/color_mapping_card.dart';

class AutoRegistrationScreen extends StatefulWidget {
  const AutoRegistrationScreen({super.key});

  @override
  State<AutoRegistrationScreen> createState() => _AutoRegistrationScreenState();
}

class _AutoRegistrationScreenState extends State<AutoRegistrationScreen> {
  final _colorMappings = <ColorMapping>[];

  String? _myUserId;
  String? _coupleId;

  bool _isLoading = false;
  bool _isUploading = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _myUserId = supabase.auth.currentUser?.id;
    _init();
  }

  Future<void> _init() async {
    _coupleId = await ScheduleService().getCoupleId();
    await _loadColorMappings();
  }

  Future<void> _loadColorMappings() async {
    if (_myUserId == null) return;
    setState(() => _isLoading = true);

    try {
      final data = await supabase
          .from('color_mappings')
          .select()
          .eq('user_id', _myUserId!);

      if (mounted) {
        setState(() {
          _colorMappings.clear();
          _colorMappings.addAll(
            (data as List).map((e) => ColorMapping.fromMap(e)).toList(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddMappingDialog() async {
    final mapping = await showDialog<ColorMapping>(
      context: context,
      builder: (ctx) => const MappingAddDialog(),
    );
    if (mapping != null) {
      await _addMapping(mapping);
    }
  }

  Future<void> _addMapping(ColorMapping mapping) async {
    if (_myUserId == null) return;

    try {
      await supabase.from('color_mappings').insert({
        'user_id': _myUserId,
        'color_hex': mapping.colorHex,
        'work_type': mapping.title,
        'start_time': mapping.startTime != null
            ? '${mapping.startTime!.hour.toString().padLeft(2, '0')}:${mapping.startTime!.minute.toString().padLeft(2, '0')}'
            : null,
        'end_time': mapping.endTime != null
            ? '${mapping.endTime!.hour.toString().padLeft(2, '0')}:${mapping.endTime!.minute.toString().padLeft(2, '0')}'
            : null,
      });

      await _loadColorMappings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('매핑이 추가되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매핑 추가 실패: $e')),
        );
      }
    }
  }

  Future<void> _onUploadPressed() async {
    if (_colorMappings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 아래에서 색상 매핑을 추가해주세요')),
      );
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      // 이미지를 base64로 변환
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final mediaType = image.mimeType ?? 'image/jpeg';

      final now = DateTime.now();

      // Supabase Edge Function 호출
      final response = await supabase.functions.invoke(
        'ocr-schedule',
        body: {
          'imageBase64': base64Image,
          'imageMediaType': mediaType,
          'colorMappings': _colorMappings.map((m) => {
            'color_hex': m.colorHex,
            'work_type': m.title,
          }).toList(),
          'targetYear': now.year,
          'targetMonth': now.month,
        },
      );

      setState(() => _isUploading = false);

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      final schedulesList = (data['schedules'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (schedulesList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('스케줄을 찾지 못했습니다. 이미지를 확인해주세요')),
          );
        }
        return;
      }

      if (mounted) {
        _showOcrResultsDialog(schedulesList, now);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR 분석 실패: $e')),
        );
      }
    }
  }

  void _showOcrResultsDialog(List<Map<String, dynamic>> schedules, DateTime month) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${month.month}월 스케줄 분석 결과 (${schedules.length}건)'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final s = schedules[index];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _hexToColor(s['color_hex'] as String? ?? '#000000'),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  '${s['date']} - ${s['work_type']}',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveOcrSchedules(schedules);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('일정 저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOcrSchedules(List<Map<String, dynamic>> schedules) async {
    if (_myUserId == null || _coupleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('커플 연결이 필요합니다')),
      );
      return;
    }

    try {
      final service = ScheduleService();
      int saved = 0;
      for (final s in schedules) {
        final dateStr = s['date'] as String?;
        final workType = s['work_type'] as String?;
        final colorHex = s['color_hex'] as String?;
        if (dateStr == null) continue;

        final schedule = Schedule(
          id: '',
          userId: _myUserId!,
          coupleId: _coupleId,
          date: DateTime.parse(dateStr),
          title: workType,
          workType: workType,
          colorHex: colorHex,
          isAnniversary: false,
        );
        await service.addSchedule(schedule);
        saved++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$saved개의 일정이 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('일정 저장 실패: $e')),
        );
      }
    }
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 자동등록'),
      ),
      body: Column(
        children: [
          // OCR 이미지 업로드 영역
          _buildOCRSection(),
          const Divider(height: 1),
          // 색상 매핑 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _colorMappings.isEmpty
                    ? _buildEmptyState()
                    : _buildMappingList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMappingDialog,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOCRSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'OCR 이미지 업로드',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border, width: 2, style: BorderStyle.solid),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: AppTheme.textSecondary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '이미지를 선택해주세요',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _onUploadPressed,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(_isUploading ? '분석 중...' : '이미지 선택'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.palette_outlined,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            '등록된 매핑이 없어요',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showAddMappingDialog,
            icon: const Icon(Icons.add),
            label: const Text('새 매핑 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _colorMappings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final mapping = _colorMappings[index];
        return ColorMappingCard(
          mapping: mapping,
          onDelete: () => _deleteMapping(mapping),
        );
      },
    );
  }

  Future<void> _deleteMapping(ColorMapping mapping) async {
    try {
      await supabase.from('color_mappings').delete().eq('id', mapping.id);
      await _loadColorMappings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매핑이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매핑 삭제 실패')),
        );
      }
    }
  }
}

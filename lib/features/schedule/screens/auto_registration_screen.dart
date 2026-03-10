import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/color_mapping.dart';
import '../../../shared/models/schedule.dart';
import '../../calendar/services/schedule_service.dart';

class AutoRegistrationScreen extends StatefulWidget {
  const AutoRegistrationScreen({super.key});

  @override
  State<AutoRegistrationScreen> createState() => _AutoRegistrationScreenState();
}

class _AutoRegistrationScreenState extends State<AutoRegistrationScreen> {
  final _colorMappings = <ColorMapping>[];

  String? _myUserId;

  bool _isLoading = false;
  bool _isUploading = false;
  String? _ocrResult;

  @override
  void initState() {
    super.initState();
    _myUserId = supabase.auth.currentUser?.id;
    _loadColorMappings();
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

  void _showAddMappingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => MappingAddDialog(
        onAdd: (mapping) async {
          await _addMapping(mapping);
        },
      ),
    );
  }

  Future<void> _addMapping(ColorMapping mapping) async {
    if (_myUserId == null) return;

    try {
      await supabase.from('color_mappings').insert({
        'user_id': _myUserId,
        'color_hex': mapping.colorHex,
        'title': mapping.title,
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
          SnackBar(content: Text('매핑이 추가되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('매핑 추가 실패')),
        );
      }
    }
  }

  void _onUploadPressed() {
    // OCR 이미지 업로드 기능 (나중에 구현)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('OCR 이미지 업로드 준비 중')),
    );
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
                    label: _isUploading ? '분석 중...' : '이미지 선택',
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
            label: '새 매핑 추가',
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

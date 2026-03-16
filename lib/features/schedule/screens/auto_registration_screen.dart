import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../calendar/services/schedule_service.dart';
import '../../../main.dart';
import 'ocr_review_screen.dart';

class AutoRegistrationScreen extends StatefulWidget {
  const AutoRegistrationScreen({super.key});

  @override
  State<AutoRegistrationScreen> createState() => _AutoRegistrationScreenState();
}

class _AutoRegistrationScreenState extends State<AutoRegistrationScreen> {
  String? _myUserId;
  String? _coupleId;
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
  }

  Future<void> _onUploadPressed() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mediaType = image.mimeType ?? 'image/jpeg';
      final now = DateTime.now();

      final response = await supabase.functions.invoke(
        'ocr-schedule',
        body: {
          'imageBase64': base64Image,
          'imageMediaType': mediaType,
          'targetYear': now.year,
          'targetMonth': now.month,
        },
      );

      setState(() => _isUploading = false);

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);

      final schedulesList =
          (data['schedules'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (schedulesList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('스케줄을 찾지 못했습니다. 이미지를 확인해주세요')),
          );
        }
        return;
      }

      final ocrYear = data['year'] as int? ?? now.year;
      final ocrMonth = data['month'] as int? ?? now.month;

      if (mounted && _myUserId != null) {
        final saved = await Navigator.push<int>(
          context,
          MaterialPageRoute(
            builder: (_) => OcrReviewScreen(
              schedules: schedulesList,
              ocrYear: ocrYear,
              ocrMonth: ocrMonth,
              userId: _myUserId!,
              coupleId: _coupleId,
            ),
          ),
        );
        if (saved != null && saved > 0 && mounted) {
          TabSwitchNotification(1).dispatch(context);
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OCR 분석 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일정 자동등록')),
      body: Padding(
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
            const SizedBox(height: 8),
            const Text(
              '달력 캡처 이미지를 선택하면 AI가 일정을 자동으로 분석합니다.\n결과를 확인하고 수정/삭제 후 제출하세요.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border, width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 56,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isUploading ? 'AI 분석 중...' : '달력 이미지를 선택해주세요',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isUploading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        onPressed: _onUploadPressed,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('이미지 선택'),
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
      ),
    );
  }
}

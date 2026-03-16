import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import '../../calendar/services/schedule_service.dart';
import '../../../main.dart';
import 'ocr_review_screen.dart';
import 'google_calendar_screen.dart';

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

  Future<void> _onOcrPressed() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
        maxHeight: 2000,
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

  void _onGoogleCalendarPressed() async {
    if (_myUserId == null) return;
    final saved = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => GoogleCalendarScreen(
          userId: _myUserId!,
          coupleId: _coupleId,
        ),
      ),
    );
    if (saved != null && saved > 0 && mounted) {
      TabSwitchNotification(1).dispatch(context);
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
              '방식을 선택하세요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '달력 사진을 AI로 분석하거나, 구글 캘린더에서 직접 가져올 수 있어요.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // OCR 카드
            _buildOptionCard(
              icon: Icons.image_search_outlined,
              iconColor: AppTheme.primary,
              title: '사진 OCR 분석',
              subtitle: '달력 캡처 이미지를 AI가 분석하여\n일정을 자동으로 추출합니다',
              badge: 'AI',
              badgeColor: AppTheme.primary,
              isLoading: _isUploading,
              onTap: _isUploading ? null : _onOcrPressed,
            ),

            const SizedBox(height: 16),

            // 구글 캘린더 카드
            _buildOptionCard(
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF4285F4),
              title: '구글 캘린더 연동',
              subtitle: '구글 계정으로 로그인하여\n캘린더 일정을 직접 가져옵니다',
              badge: '정확도 100%',
              badgeColor: const Color(0xFF34A853),
              isLoading: false,
              onTap: _onGoogleCalendarPressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            color: badgeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

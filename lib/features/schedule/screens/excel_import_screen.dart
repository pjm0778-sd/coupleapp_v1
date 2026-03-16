import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme.dart';
import '../../../core/supabase_client.dart';
import 'ocr_review_screen.dart';

class ExcelImportScreen extends StatefulWidget {
  final String myUserId;
  final String? coupleId;
  final String? partnerId;
  final String? partnerNickname;

  const ExcelImportScreen({
    super.key,
    required this.myUserId,
    this.coupleId,
    this.partnerId,
    this.partnerNickname,
  });

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final _nameCtrl = TextEditingController();
  final _imagePicker = ImagePicker();

  int _targetYear = DateTime.now().year;
  int _targetMonth = DateTime.now().month;
  bool _isLoading = false;
  String? _loadingMethod; // 'photo' | 'excel' | 'sheets'

  static const _excelGreen = Color(0xFF1D6F42);
  static const _sheetsBlue = Color(0xFF4285F4);
  static const _amber = Color(0xFFF59E0B);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _hasName => _nameCtrl.text.trim().isNotEmpty;

  void _requireName() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('근무표에 표시된 내 이름을 먼저 입력해주세요')),
    );
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final months = <({int year, int month})>[];
    for (int i = -3; i <= 6; i++) {
      int m = now.month + i;
      int y = now.year;
      while (m <= 0) {
        m += 12;
        y--;
      }
      while (m > 12) {
        m -= 12;
        y++;
      }
      months.add((year: y, month: m));
    }

    final selected = await showDialog<({int year, int month})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대상 월 선택'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (ctx, i) {
              final m = months[i];
              final isSelected =
                  m.year == _targetYear && m.month == _targetMonth;
              return ListTile(
                title: Text('${m.year}년 ${m.month}월'),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppTheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _targetYear = selected.year;
        _targetMonth = selected.month;
      });
    }
  }

  // ── 사진 OCR ────────────────────────────────────────────────
  Future<void> _onPhotoPressed() async {
    if (!_hasName) {
      _requireName();
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 2400,
    );
    if (image == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _loadingMethod = 'photo';
    });

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mediaType = image.mimeType ?? 'image/jpeg';
      final name = _nameCtrl.text.trim();

      final response = await supabase.functions.invoke(
        'schedule-table-ocr',
        body: {
          'imageBase64': base64Image,
          'imageMediaType': mediaType,
          'targetName': name,
          'targetYear': _targetYear,
          'targetMonth': _targetMonth,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);

      final schedules =
          (data['schedules'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (schedules.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$name"의 근무를 찾지 못했습니다. 이름과 이미지를 확인해주세요'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        await _goToReview(
          schedules,
          data['year'] as int? ?? _targetYear,
          data['month'] as int? ?? _targetMonth,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMethod = null;
        });
      }
    }
  }

  // ── 엑셀 파일 ────────────────────────────────────────────────
  Future<void> _onExcelPressed() async {
    if (!_hasName) {
      _requireName();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null ||
        result.files.single.bytes == null ||
        !mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMethod = 'excel';
    });

    try {
      final bytes = result.files.single.bytes!;
      final base64File = base64Encode(bytes);
      final name = _nameCtrl.text.trim();

      final response = await supabase.functions.invoke(
        'excel-schedule-parse',
        body: {
          'fileBase64': base64File,
          'myName': name,
          'targetYear': _targetYear,
          'targetMonth': _targetMonth,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['error'] != null) throw Exception(data['error']);

      final schedules =
          (data['mySchedules'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (schedules.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('"$name"의 근무를 찾지 못했습니다. 근무표의 이름과 정확히 일치하는지 확인해주세요'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        await _goToReview(
          schedules,
          data['year'] as int? ?? _targetYear,
          data['month'] as int? ?? _targetMonth,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 파싱 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMethod = null;
        });
      }
    }
  }

  // ── Google Sheets ────────────────────────────────────────────
  void _onSheetsPressed() {
    if (!_hasName) {
      _requireName();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Sheets 연동은 곧 지원됩니다')),
    );
  }

  // ── OcrReviewScreen으로 이동 ─────────────────────────────────
  Future<void> _goToReview(
    List<Map<String, dynamic>> schedules,
    int year,
    int month,
  ) async {
    final saved = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrReviewScreen(
          schedules: schedules,
          ocrYear: year,
          ocrMonth: month,
          userId: widget.myUserId,
          coupleId: widget.coupleId,
          isGoogleCalendar: false,
        ),
      ),
    );
    if (saved != null && saved > 0 && mounted) {
      Navigator.pop(context, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('근무표 불러오기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNameSection(),
            const SizedBox(height: 24),
            const Text(
              '가져오기 방법',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            _buildMethodCard(
              icon: Icons.photo_camera_outlined,
              iconColor: AppTheme.primary,
              title: '인쇄된 근무표 사진',
              subtitle: '출력된 근무표를 사진으로 찍거나 갤러리에서 선택하세요',
              badge: 'AI 분석',
              badgeColor: AppTheme.primary,
              loadingKey: 'photo',
              onTap: _onPhotoPressed,
            ),
            const SizedBox(height: 12),
            _buildMethodCard(
              icon: Icons.upload_file_outlined,
              iconColor: _excelGreen,
              title: '엑셀 파일 (.xlsx)',
              subtitle: '엑셀 근무표 파일을 직접 업로드 — 정확도 100%',
              badge: 'Premium',
              badgeColor: _amber,
              loadingKey: 'excel',
              onTap: _onExcelPressed,
            ),
            const SizedBox(height: 12),
            _buildMethodCard(
              icon: Icons.link_outlined,
              iconColor: _sheetsBlue,
              title: 'Google Sheets 링크',
              subtitle: '구글 시트로 공유된 근무표 URL을 입력하세요',
              badge: '준비 중',
              badgeColor: AppTheme.textSecondary,
              loadingKey: 'sheets',
              onTap: _onSheetsPressed,
              comingSoon: true,
            ),
            const SizedBox(height: 24),
            _buildTipBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, size: 15, color: AppTheme.primary),
              SizedBox(width: 6),
              Text(
                '근무표에 표시된 내 이름',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              SizedBox(width: 3),
              Text(
                '*',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '예: 홍길동',
              hintStyle: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                '대상 월',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _selectMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_targetYear년 $_targetMonth월',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required String loadingKey,
    required VoidCallback onTap,
    bool comingSoon = false,
  }) {
    final isThisLoading = _isLoading && _loadingMethod == loadingKey;
    final isDisabled =
        (_isLoading && _loadingMethod != loadingKey) || comingSoon;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isThisLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
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
                    const SizedBox(height: 3),
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
                color: AppTheme.textSecondary.withOpacity(0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                '사용 팁',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...[
            '근무표에 표시된 이름과 정확히 일치해야 합니다',
            '사진은 표 전체가 선명하게 보이도록 찍어주세요',
            '엑셀 파일(.xlsx)은 직접 파싱하므로 정확도 100%입니다',
            '엑셀 파일이 없다면 사진으로 찍어서 AI 분석을 이용하세요',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
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
}

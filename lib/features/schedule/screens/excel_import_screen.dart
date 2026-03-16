import 'package:flutter/material.dart';
import '../../../core/theme.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('근무표 불러오기')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              SizedBox(height: 20),
              Text(
                '준비 중입니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '엑셀 근무표 불러오기 기능은\n곧 업데이트될 예정입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

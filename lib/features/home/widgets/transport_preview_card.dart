import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../transport/screens/transport_search_screen.dart';

class TransportPreviewCard extends StatelessWidget {
  final String fromStation;
  final String toStation;
  final DateTime? nextDate;

  const TransportPreviewCard({
    super.key,
    required this.fromStation,
    required this.toStation,
    this.nextDate,
  });

  @override
  Widget build(BuildContext context) {
    // 역명 표시 포맷: "서울역 (KTX)" → "서울역"
    final fromName = _shortName(fromStation);
    final toName = _shortName(toStation);

    final dateLabel = nextDate != null ? _formatDate(nextDate!) : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransportSearchScreen(
            fromStation: fromStation,
            toStation: toStation,
            initialDate: nextDate,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.train_outlined,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // 경로 + 날짜
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '교통편 검색',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fromName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward,
                            size: 14, color: AppTheme.textSecondary),
                      ),
                      Flexible(
                        child: Text(
                          toName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 화살표
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  String _shortName(String station) {
    return station.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }

  String _formatDate(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[d.weekday - 1];
    return '${d.month}월 ${d.day}일 ($wd) 교통편 기준';
  }
}

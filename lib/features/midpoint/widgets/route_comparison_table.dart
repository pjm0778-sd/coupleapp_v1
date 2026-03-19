import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../models/midpoint_result.dart';

class RouteComparisonTable extends StatelessWidget {
  final RouteInfo myRoute;
  final RouteInfo partnerRoute;

  const RouteComparisonTable({
    super.key,
    required this.myRoute,
    required this.partnerRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // 헤더
          _Row(
            isHeader: true,
            left: '구분',
            center: '나',
            right: '상대방',
          ),
          const Divider(height: 1, color: AppTheme.border),
          _Row(
            left: '교통수단',
            center: myRoute.transitLabel,
            right: partnerRoute.transitLabel,
          ),
          const Divider(height: 1, color: AppTheme.border),
          _Row(
            left: '출발지',
            center: myRoute.originName,
            right: partnerRoute.originName,
          ),
          const Divider(height: 1, color: AppTheme.border),
          _Row(
            left: '거리',
            center: '${myRoute.distanceKm.toStringAsFixed(0)}km',
            right: '${partnerRoute.distanceKm.toStringAsFixed(0)}km',
          ),
          const Divider(height: 1, color: AppTheme.border),
          _Row(
            left: '소요시간',
            center: myRoute.durationLabel,
            right: partnerRoute.durationLabel,
            highlight: true,
          ),
          const Divider(height: 1, color: AppTheme.border),
          _Row(
            left: '예상비용',
            center: myRoute.costLabel,
            right: partnerRoute.costLabel,
          ),
          // 추정값 경고
          if (myRoute.isEstimated || partnerRoute.isEstimated)
            _EstimatedWarning(
              myNote: myRoute.isEstimated ? myRoute.estimatedNote : null,
              partnerNote:
                  partnerRoute.isEstimated ? partnerRoute.estimatedNote : null,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String left;
  final String center;
  final String right;
  final bool isHeader;
  final bool highlight;

  const _Row({
    required this.left,
    required this.center,
    required this.right,
    this.isHeader = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isHeader
        ? AppTheme.background
        : highlight
            ? AppTheme.accent.withOpacity(0.06)
            : AppTheme.surface;

    final textStyle = TextStyle(
      fontSize: isHeader ? 12 : 13,
      fontWeight: isHeader || highlight ? FontWeight.w600 : FontWeight.normal,
      color: isHeader ? AppTheme.textSecondary : AppTheme.textPrimary,
    );

    return Container(
      color: bgColor,
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(left,
                    style: textStyle.copyWith(color: AppTheme.textSecondary)),
              ),
            ),
            const VerticalDivider(width: 1, color: AppTheme.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(center, style: textStyle, textAlign: TextAlign.center),
              ),
            ),
            const VerticalDivider(width: 1, color: AppTheme.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(right, style: textStyle, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimatedWarning extends StatelessWidget {
  final String? myNote;
  final String? partnerNote;

  const _EstimatedWarning({this.myNote, this.partnerNote});

  @override
  Widget build(BuildContext context) {
    final note = myNote ?? partnerNote ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 14, color: Colors.orange[700]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(note,
                style: TextStyle(fontSize: 11, color: Colors.orange[800])),
          ),
        ],
      ),
    );
  }
}

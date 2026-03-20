import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../transport/screens/transport_search_screen.dart';
import '../../midpoint/screens/midpoint_search_screen.dart';

class TravelTogetherCard extends StatelessWidget {
  final String? fromStation;
  final String? toStation;
  final DateTime? nextDate;

  const TravelTogetherCard({
    super.key,
    this.fromStation,
    this.toStation,
    this.nextDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더 ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.explore_outlined,
                    color: AppTheme.primary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '우리의 이동',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── 서로에게 가는 길 ────────────────────────────────────
          _TransportRow(
            fromStation: fromStation,
            toStation: toStation,
            nextDate: nextDate,
          ),

          // ── 구분선 ──────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppTheme.border),
          ),

          // ── 중간지점 찾기 ────────────────────────────────────────
          _MidpointRow(),
        ],
      ),
    );
  }
}

// ─── 서로에게 가는 길 ────────────────────────────────────────────────────────

class _TransportRow extends StatelessWidget {
  final String? fromStation;
  final String? toStation;
  final DateTime? nextDate;

  const _TransportRow({this.fromStation, this.toStation, this.nextDate});

  @override
  Widget build(BuildContext context) {
    final hasInfo = fromStation != null && toStation != null;
    final fromName = hasInfo ? _shortName(fromStation!) : null;
    final toName = hasInfo ? _shortName(toStation!) : null;

    return GestureDetector(
      onTap: hasInfo
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransportSearchScreen(
                    fromStation: fromStation!,
                    toStation: toStation!,
                    initialDate: nextDate,
                  ),
                ),
              )
          : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.train_outlined,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '서로에게 가는 길',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (hasInfo)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fromName!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 11,
                            color: AppTheme.accent,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            toName!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      '설정에서 출발역을 등록해 보세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            // 화살표
            Icon(
              Icons.chevron_right,
              size: 18,
              color: hasInfo ? AppTheme.textTertiary : AppTheme.border,
            ),
          ],
        ),
      ),
    );
  }

  String _shortName(String station) {
    return station.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }
}

// ─── 중간지점 찾기 ─────────────────────────────────────────────────────────────

class _MidpointRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MidpointSearchScreen()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: AppTheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // 텍스트
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '중간지점 찾기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '우리 사이 딱 중간 어딘가에서',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // 화살표
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class RelationshipTimelineScreen extends StatelessWidget {
  final DateTime startedAt;
  final String? myNickname;
  final String? partnerNickname;

  const RelationshipTimelineScreen({
    super.key,
    required this.startedAt,
    this.myNickname,
    this.partnerNickname,
  });

  List<_Milestone> _buildMilestones() {
    final now = DateTime.now();
    final milestones = <_Milestone>[];

    // 1. Start date (만난 날 = D+1)
    milestones.add(_Milestone(
      date: startedAt,
      label: '우리의 시작 ❤️',
      daysCount: 1,
      isPast: true,
      isSpecial: true,
    ));

    // 2. 100-day milestones: D+N = N번째 날 = startedAt + (N-1)일
    for (int i = 100; i <= 3650; i += 100) {
      final date = startedAt.add(Duration(days: i - 1));
      if (date.isAfter(now.add(const Duration(days: 365)))) break;
      milestones.add(_Milestone(
        date: date,
        label: 'D+$i',
        daysCount: i,
        isPast: date.isBefore(now),
        isSpecial: i % 1000 == 0,
      ));
    }

    // 3. Anniversaries: daysCount도 D+1 기준으로 +1
    for (int year = 1; year <= 10; year++) {
      final date = DateTime(
        startedAt.year + year,
        startedAt.month,
        startedAt.day,
      );
      if (date.isAfter(now.add(const Duration(days: 400)))) break;
      final daysFromStart = date.difference(startedAt).inDays + 1;
      milestones.add(_Milestone(
        date: date,
        label: '$year주년 기념일 🎉',
        daysCount: daysFromStart,
        isPast: date.isBefore(now),
        isSpecial: true,
      ));
    }

    // Sort chronologically
    milestones.sort((a, b) => a.date.compareTo(b.date));
    return milestones;
  }

  @override
  Widget build(BuildContext context) {
    final milestones = _buildMilestones();
    final now = DateTime.now();
    final daysTogether = now.difference(startedAt).inDays + 1; // 만난 날 = D+1
    final partnerName = partnerNickname ?? '파트너';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('우리의 이야기'),
        backgroundColor: AppTheme.surface,
      ),
      body: Column(
        children: [
          // Header card with D+days count
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D5E58), Color(0xFF3D7068)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [AppTheme.cardShadow],
            ),
            child: Column(
              children: [
                Text(
                  '$partnerName 와 함께',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'D+$daysTogether',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${startedAt.year}.${startedAt.month.toString().padLeft(2, '0')}.${startedAt.day.toString().padLeft(2, '0')} 부터',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),

          // Timeline list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              itemCount: milestones.length,
              itemBuilder: (ctx, i) {
                final m = milestones[i];
                final isLast = i == milestones.length - 1;
                return _TimelineItem(
                  milestone: m,
                  isLast: isLast,
                  isFirst: i == 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _Milestone {
  final DateTime date;
  final String label;
  final int daysCount;
  final bool isPast;
  final bool isSpecial;

  const _Milestone({
    required this.date,
    required this.label,
    required this.daysCount,
    required this.isPast,
    required this.isSpecial,
  });
}

// ── Timeline item widget ──────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final _Milestone milestone;
  final bool isLast;
  final bool isFirst;

  const _TimelineItem({
    required this.milestone,
    required this.isLast,
    required this.isFirst,
  });

  String _formattedDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isFuture = !milestone.isPast;

    // Dot sizing
    final double dotSize = milestone.isSpecial ? 16 : 12;

    // D-days countdown for upcoming milestones
    final int daysUntil = milestone.date.difference(now).inDays;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left: line + dot column ──────────────────────────
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical line (skip line above first item, below last)
                if (!isFirst)
                  Positioned(
                    top: 0,
                    bottom: isLast ? dotSize / 2 + 8 : 0,
                    left: 19,
                    child: Container(
                      width: 2,
                      color: AppTheme.primary.withOpacity(0.25),
                    ),
                  ),
                if (!isLast)
                  Positioned(
                    top: dotSize / 2 + 8,
                    bottom: 0,
                    left: 19,
                    child: Container(
                      width: 2,
                      color: AppTheme.primary.withOpacity(0.25),
                    ),
                  ),

                // Dot
                Positioned(
                  top: 16,
                  child: isFuture
                      ? Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.accent,
                              width: 2,
                            ),
                            color: AppTheme.background,
                          ),
                        )
                      : Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: milestone.isSpecial
                                ? AppTheme.accent
                                : AppTheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: (milestone.isSpecial
                                        ? AppTheme.accent
                                        : AppTheme.primary)
                                    .withOpacity(0.35),
                                blurRadius: 6,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right: content card ──────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: _buildCard(isFuture, daysUntil),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isFuture, int daysUntil) {
    if (!isFuture && milestone.isSpecial) {
      // Past special milestone: gradient card
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D7068), Color(0xFF2D5E58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [AppTheme.subtleShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    milestone.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (milestone.daysCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'D+${milestone.daysCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formattedDate(milestone.date),
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (isFuture) {
      // Upcoming milestone: light tinted card with badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.accentLight.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.accent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // "다가오는" badge
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '다가오는',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    milestone.label,
                    style: TextStyle(
                      color: AppTheme.textPrimary.withOpacity(0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formattedDate(milestone.date),
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                // D-X countdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    daysUntil == 0 ? '오늘!' : 'D-$daysUntil',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Past normal milestone: plain white card
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.label,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formattedDate(milestone.date),
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Checkmark for completed
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withOpacity(0.1),
            ),
            child: Icon(
              Icons.check,
              size: 15,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

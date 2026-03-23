import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class LongingGaugeCard extends StatefulWidget {
  final int longingDays;      // 마지막 만남 이후 일수
  final double progress;      // 0.0~1.0 (게이지 채워진 비율)
  final String lastDateLabel; // "3월 12일" or ""
  final String nextDateLabel; // "4월 2일" or ""
  final int? daysUntil;       // 다음 만남까지 D-n (null이면 미등록)

  const LongingGaugeCard({
    super.key,
    required this.longingDays,
    required this.progress,
    this.lastDateLabel = '',
    this.nextDateLabel = '',
    this.daysUntil,
  });

  @override
  State<LongingGaugeCard> createState() => _LongingGaugeCardState();
}

class _LongingGaugeCardState extends State<LongingGaugeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(LongingGaugeCard old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _progressAnim =
          Tween<double>(begin: 0, end: widget.progress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = widget.daysUntil == 0;
    final hasNextDate = widget.nextDateLabel.isNotEmpty;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8F2), Color(0xFFFFF2F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [AppTheme.cardShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 헤더 행 ──────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('💗', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 6),
                    const Text(
                      '보고 싶은 마음',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (hasNextDate && widget.daysUntil != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          isToday ? '오늘 만나요! 💕' : 'D-${widget.daysUntil}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── 메인 문구 ─────────────────────────────────────
                if (isToday)
                  const Text(
                    '오늘 드디어 만나요!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  )
                else
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: '보고 싶은 지  ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: '${widget.longingDays}일',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            height: 1.0,
                          ),
                        ),
                        const TextSpan(
                          text: '째예요',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),

                // ── 게이지 ────────────────────────────────────────
                if (hasNextDate) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final fillWidth =
                          (_progressAnim.value * totalWidth).clamp(0.0, totalWidth);
                      const dotSize = 14.0;
                      final dotLeft =
                          (fillWidth - dotSize / 2).clamp(0.0, totalWidth - dotSize);

                      return SizedBox(
                        height: 14, // track height + dot overflow
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Track
                            Positioned(
                              top: 3,
                              left: 0,
                              right: 0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 8,
                                  color: AppTheme.border,
                                ),
                              ),
                            ),
                            // Fill
                            Positioned(
                              top: 3,
                              left: 0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  width: fillWidth,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFD4A0B0), // muted rose
                                        Color(0xFFCBA258), // gold (accent)
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Dot (current position)
                            if (_progressAnim.value > 0.02)
                              Positioned(
                                left: dotLeft,
                                top: 0,
                                child: Container(
                                  width: dotSize,
                                  height: dotSize,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.accent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accent
                                            .withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // ── 날짜 라벨 ────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lastDateLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Text(
                            '마지막 만남',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.nextDateLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                          const Text(
                            '다음 만남',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  // 다음 만남 미등록 안내
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '다음 만남을 캘린더에 등록해 보세요',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // ── 캡션 ─────────────────────────────────────────
                Center(
                  child: Text(
                    '"보고 싶은 마음, 함께 세어요"',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

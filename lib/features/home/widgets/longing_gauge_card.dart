import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class LongingGaugeCard extends StatefulWidget {
  final int longingDays;
  final double progress;
  final String lastDateLabel;
  final String nextDateLabel;
  final int? daysUntil;

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
      _progressAnim = Tween<double>(begin: 0, end: widget.progress).animate(
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
    final hasNextDate = widget.nextDateLabel.isNotEmpty;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8F2), Color(0xFFFFF2F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [AppTheme.cardShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 보고싶은 N일째 + D-day ───────────────────────
                Row(
                  children: [
                    const Text('💗', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      '보고싶은 지 ${widget.longingDays}일째',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (hasNextDate && widget.daysUntil != null)
                      Text(
                        widget.daysUntil == 0 ? '오늘 만나요! 💕' : 'D-${widget.daysUntil}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── 게이지 ────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final fillWidth = hasNextDate
                        ? (_progressAnim.value * totalWidth).clamp(0.0, totalWidth)
                        : 0.0;
                    const dotSize = 12.0;
                    final dotLeft =
                        (fillWidth - dotSize / 2).clamp(0.0, totalWidth - dotSize);

                    return SizedBox(
                      height: 12,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 2,
                            left: 0,
                            right: 0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Container(height: 6, color: AppTheme.border),
                            ),
                          ),
                          if (hasNextDate)
                            Positioned(
                              top: 2,
                              left: 0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: Container(
                                  width: fillWidth,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFD4A0B0), Color(0xFFCBA258)],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (hasNextDate && _progressAnim.value > 0.02)
                            Positioned(
                              left: dotLeft,
                              top: 0,
                              child: Container(
                                width: dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.accent, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent.withValues(alpha: 0.3),
                                      blurRadius: 4,
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
                const SizedBox(height: 6),

                // ── 날짜 라벨 ────────────────────────────────────
                Row(
                  children: [
                    if (widget.lastDateLabel.isNotEmpty)
                      Text(
                        '${widget.lastDateLabel} 마지막',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    const Spacer(),
                    if (hasNextDate)
                      Text(
                        '${widget.nextDateLabel} 다음',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.accent,
                        ),
                      )
                    else
                      const Text(
                        '다음 만남을 등록해 보세요',
                        style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

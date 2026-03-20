import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/holiday_service.dart';

class DDayWidget extends StatelessWidget {
  final int? days;
  final String? partnerNickname;
  final int? nextDateDays;

  const DDayWidget({
    super.key,
    this.days,
    this.partnerNickname,
    this.nextDateDays,
  });

  @override
  Widget build(BuildContext context) {
    final displayDays = days != null ? days! + 1 : 0;
    final label = partnerNickname != null
        ? '$partnerNickname과 함께한 지'
        : '우리가 함께한 지';

    final today = DateTime.now();
    final todayHolidays = HolidayService().getHolidays(today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A2A4A), // Navy
            Color(0xFF243656), // Navy 밝게
          ],
        ),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 오늘 기념일/공휴일 배너
          if (todayHolidays.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                todayHolidays.map((h) => '${h.emoji} ${h.name}').join('  ·  '),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // D+day 숫자
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.notoSansKr(
                        color: Colors.white.withValues(alpha:0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'D+',
                            style: GoogleFonts.notoSansKr(
                              color: AppTheme.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: '$displayDays',
                            style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: '일',
                            style: GoogleFonts.notoSansKr(
                              color: Colors.white.withValues(alpha:0.7),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (partnerNickname != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: AppTheme.accent,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            partnerNickname!,
                            style: GoogleFonts.notoSansKr(
                              color: AppTheme.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Gold 별 장식 (오른쪽)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha:0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '✦',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 다음 데이트까지
          if (nextDateDays != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    color: AppTheme.accent,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    nextDateDays == 0
                        ? '오늘 데이트! 💕'
                        : '다음 데이트까지 D-$nextDateDays',
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

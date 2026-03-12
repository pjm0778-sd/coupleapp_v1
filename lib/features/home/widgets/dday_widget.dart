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

    // 오늘 공휴일/기념일 확인
    final today = DateTime.now();
    final todayHolidays = HolidayService().getHolidays(today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary,
            AppTheme.primary.withOpacity(0.75),
            const Color(0xFFFF6B9D),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 오늘 기념일/공휴일 배너
          if (todayHolidays.isNotEmpty) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                todayHolidays
                    .map((h) => '${h.emoji} ${h.name}')
                    .join('  ·  '),
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
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'D+',
                            style: GoogleFonts.notoSansKr(
                              color: Colors.white70,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: '$displayDays',
                            style: GoogleFonts.notoSansKr(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: '일',
                            style: GoogleFonts.notoSansKr(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 하트 아이콘 (오른쪽)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),

          // 다음 데이트까지
          if (nextDateDays != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      color: Colors.white70, size: 14),
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

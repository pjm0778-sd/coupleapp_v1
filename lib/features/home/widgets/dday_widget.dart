import 'package:flutter/material.dart';
import '../../../core/theme.dart';

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
    final screenHeight = MediaQuery.of(context).size.height;
    final displayDays = days != null ? days! + 1 : 0;
    final label = partnerNickname != null ? '$partnerNickname과 만난지' : '만난지';

    return SizedBox(
      height: screenHeight / 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'D+$displayDays',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  if (nextDateDays != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            color: Colors.white60, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '다음 데이트까지 D-$nextDateDays',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

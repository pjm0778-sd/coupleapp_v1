import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class DDayWidget extends StatelessWidget {
  final int? days;
  final DateTime? startedAt;
  final VoidCallback onTap;

  const DDayWidget({
    super.key,
    this.days,
    this.startedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayDays = days != null ? days : 0;
    final displayDate = startedAt != null
        ? '${startedAt.year}년 ${startedAt.month}월 ${startedAt.day}일'
        : '날짜 미설정';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // 커플 아이콘
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.favorite,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '연애',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'D +',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // D-day
            Text(
              displayDays.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(height: 8),
            // 시작일
            Text(
              displayDate,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            // 탭하여 설정 메시지
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.edit_outlined,
                  color: Colors.white70,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '탭하여 설정',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

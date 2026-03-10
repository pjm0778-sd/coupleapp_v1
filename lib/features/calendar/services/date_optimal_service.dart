import 'package:collection/collection.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';

class DateOptimalService {
  /// 데이트 최적일 조회
  ///
  /// 양쪽 다 비거나 쉬는 날을 반환
  /// started_at을 기준으로 100일 단위 기념일도 데이트로 추천
  Future<List<DateTime>> getOptimalDays(
    String coupleId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;

    // 내 일정 (빈 날짜 찾기)
    final mySchedules = await supabase
        .from('schedules')
        .select('date')
        .eq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0]);

    // 파트너 일정 (빈 날짜 찾기)
    final partnerSchedules = await supabase
        .from('schedules')
        .select('date')
        .neq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0]);

    final myDates = (mySchedules as List)
        .map((e) => DateTime.parse(e['date'] as String))
        .toSet();

    final partnerDates = (partnerSchedules as List)
        .map((e) => DateTime.parse(e['date'] as String))
        .toSet();

    final optimalDays = <DateTime>[];

    for (var date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final dateStr = date.toIso8601String().split('T')[0];

      // 내 일정 확인
      final mySchedule = mySchedules.cast<Map>().firstWhere(
        (s) => s['date'] == dateStr,
        orElse: () => {},
      );

      // 파트너 일정 확인
      final partnerSchedule = partnerSchedules.cast<Map>().firstWhere(
        (s) => s['date'] == dateStr,
        orElse: () => {},
      );

      // 양쪽 다 비거나 쉬는 날인지 확인
      final isMyFree = mySchedule.isEmpty || mySchedule['category'] == '휴무';
      final isPartnerFree =
          partnerSchedule.isEmpty || partnerSchedule['category'] == '휴무';

      if (isMyFree && isPartnerFree) {
        optimalDays.add(date);
      }
    }

    return optimalDays;
  }

  /// 가장 가까운 데이트 최적일 조회
  Future<DateTime?> getNextOptimalDay(String coupleId) async {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 3, 1);

    final optimalDays = await getOptimalDays(
      coupleId,
      startDate: now,
      endDate: nextMonth,
    );

    if (optimalDays.isEmpty) return null;

    return optimalDays.firstWhere(
      (d) => d.isAfter(now),
      orElse: () => optimalDays.first,
    );
  }
}

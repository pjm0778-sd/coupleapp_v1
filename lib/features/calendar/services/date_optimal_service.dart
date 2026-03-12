import '../../../core/supabase_client.dart';

class DateOptimalService {
  /// ?곗씠??理쒖쟻??議고쉶
  ///
  /// ?묒そ ??鍮꾧굅???щ뒗 ?좎쓣 諛섑솚
  /// started_at??湲곗??쇰줈 100???⑥쐞 湲곕뀗?쇰룄 ?곗씠?몃줈 異붿쿇
  Future<List<DateTime>> getOptimalDays(
    String coupleId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final currentUserId = supabase.auth.currentUser!.id;

    // ???쇱젙 (鍮??좎쭨 李얘린)
    final mySchedules = await supabase
        .from('schedules')
        .select('date')
        .eq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .gte('date', startDate.toIso8601String().split('T')[0])
        .lte('date', endDate.toIso8601String().split('T')[0]);

    // ?뚰듃???쇱젙 (鍮??좎쭨 李얘린)
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

      // ???쇱젙 ?뺤씤
      final mySchedule = mySchedules.cast<Map>().firstWhere(
        (s) => s['date'] == dateStr,
        orElse: () => {},
      );

      // ?뚰듃???쇱젙 ?뺤씤
      final partnerSchedule = partnerSchedules.cast<Map>().firstWhere(
        (s) => s['date'] == dateStr,
        orElse: () => {},
      );

      // ?묒そ ??鍮꾧굅???щ뒗 ?좎씤吏 ?뺤씤
      final isMyFree = mySchedule.isEmpty || mySchedule['category'] == '?대Т';
      final isPartnerFree =
          partnerSchedule.isEmpty || partnerSchedule['category'] == '?대Т';

      if (isMyFree && isPartnerFree) {
        optimalDays.add(date);
      }
    }

    return optimalDays;
  }

  /// 媛??媛源뚯슫 ?곗씠??理쒖쟻??議고쉶
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

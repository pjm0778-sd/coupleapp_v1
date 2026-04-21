import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';

class HomeService {
  bool _isOffCategory(String? category) =>
      category == '휴무' || category == '쉬는날';

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, List<Schedule>>> getSchedulesForDate(
    String coupleId,
    DateTime date,
  ) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      return {'mine': <Schedule>[], 'partner': <Schedule>[]};
    }

    final rows = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .or('date.eq.$dateStr,and(start_date.lte.$dateStr,end_date.gte.$dateStr)')
        .order('start_time', ascending: true);

    final mine = <Schedule>[];
    final partner = <Schedule>[];

    for (final row in (rows as List)) {
      final schedule = Schedule.fromMap(row as Map<String, dynamic>);

      // Couple-owned schedules should appear in both columns on home cards.
      if (schedule.ownerType == 'couple') {
        mine.add(schedule);
        partner.add(schedule);
        continue;
      }

      if (schedule.userId == currentUserId) {
        mine.add(schedule);
      } else {
        partner.add(schedule);
      }
    }

    return {'mine': mine, 'partner': partner};
  }

  /// D-day 정보 + 내 애인 닉네임 조회
  Future<Map<String, dynamic>> getDDays(String coupleId) async {
    final coupleData = await supabase
        .from('couples')
        .select('started_at, user1_id, user2_id')
        .eq('id', coupleId)
        .maybeSingle();

    if (coupleData == null) return {};
    final startedAt = coupleData['started_at'] as String?;
    if (startedAt == null) return {};

    final startedDate = DateTime.parse(startedAt);
    final now = DateTime.now();
    final diff = now.difference(startedDate);

    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return {};
    final partnerId = coupleData['user1_id'] == currentUserId
        ? coupleData['user2_id']
        : coupleData['user1_id'];

    String? partnerNickname;
    if (partnerId != null) {
      final partner = await supabase
          .from('profiles')
          .select('nickname')
          .eq('id', partnerId as String)
          .maybeSingle();
      partnerNickname = partner?['nickname'] as String?;
    }

    return {
      'days': diff.inDays + 1, // 만난 날 = D+1 기준
      'started_at': startedAt,
      'partner_nickname': partnerNickname,
    };
  }

  /// 오늘의 일정 요약
  Future<Map<String, List<Schedule>>> getTodaySchedules(String coupleId) async {
    return getSchedulesForDate(coupleId, DateTime.now());
  }

  /// 내일의 일정 요약
  Future<Map<String, List<Schedule>>> getTomorrowSchedules(
    String coupleId,
  ) async {
    return getSchedulesForDate(coupleId, DateTime.now().add(const Duration(days: 1)));
  }

  /// 다음 데이트 조회 (직접 등록한 데이트 일정 + 시스템 기념일 포함)
  Future<Map<String, dynamic>?> getNextDateSchedule(String coupleId) async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];

    // 1. DB에서 '데이트' 카테고리이거나 is_date=true인 가장 가까운 일정 조회
    final result = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .or('category.eq.데이트,is_date.eq.true')
        .gte('date', todayStr)
        .order('date', ascending: true)
        .limit(1)
        .maybeSingle();

    Schedule? dbSchedule;
    if (result != null) {
      dbSchedule = Schedule.fromMap(result);
    }

    // 2. 시스템 기념일 계산 (100일 단위, 1년 단위)
    final coupleData = await supabase
        .from('couples')
        .select('started_at')
        .eq('id', coupleId)
        .maybeSingle();

    Schedule? annivSchedule;
    if (coupleData != null && coupleData['started_at'] != null) {
      final startedAt = DateTime.parse(coupleData['started_at'] as String);
      final anniversaries = <Schedule>[];

      // 100일 단위 (1000일까지)
      for (int i = 1; i <= 10; i++) {
        final d = startedAt.add(Duration(days: (i * 100) - 1));
        if (!d.isBefore(DateTime(now.year, now.month, now.day))) {
          anniversaries.add(
            Schedule(
              id: 'anniv_100_$i',
              userId: 'system',
              coupleId: coupleId,
              date: d,
              title: '${i * 100}일',
              category: '기념일',
              isAnniversary: true,
            ),
          );
        }
      }

      // 1년 단위 (10년까지)
      for (int i = 1; i <= 10; i++) {
        final d = DateTime(startedAt.year + i, startedAt.month, startedAt.day);
        if (!d.isBefore(DateTime(now.year, now.month, now.day))) {
          anniversaries.add(
            Schedule(
              id: 'anniv_yr_$i',
              userId: 'system',
              coupleId: coupleId,
              date: d,
              title: '$i주년',
              category: '기념일',
              isAnniversary: true,
            ),
          );
        }
      }

      if (anniversaries.isNotEmpty) {
        anniversaries.sort((a, b) => a.date.compareTo(b.date));
        annivSchedule = anniversaries.first;
      }
    }

    // 3. DB 일정과 기념일 중 더 가까운 것 선택
    Schedule? next;
    if (dbSchedule != null && annivSchedule != null) {
      next = dbSchedule.date.isBefore(annivSchedule.date)
          ? dbSchedule
          : annivSchedule;
    } else {
      next = dbSchedule ?? annivSchedule;
    }

    if (next == null) return null;

    final targetDate = DateTime(next.date.year, next.date.month, next.date.day);
    final nowDate = DateTime(now.year, now.month, now.day);
    final diff = targetDate.difference(nowDate).inDays;

    return {'schedule': next, 'days_until': diff};
  }

  /// 마지막 데이트 조회 (오늘 이전 가장 최근 커플 데이트)
  Future<Map<String, dynamic>?> getLastDateSchedule(String coupleId) async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayStr =
        '${todayDate.year}-${todayDate.month.toString().padLeft(2, '0')}-${todayDate.day.toString().padLeft(2, '0')}';

    final results = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .or('category.eq.데이트,category.eq.여행,is_date.eq.true,owner_type.eq.couple')
        .lt('date', todayStr)
        .order('date', ascending: false)
        .limit(200);

    if ((results as List).isEmpty) return null;

    Schedule? lastSchedule;
    DateTime? lastMetDate;

    for (final row in results) {
      final schedule = Schedule.fromMap(row);
      final candidateSource = schedule.endDate ?? schedule.date;
      final candidateDate = DateTime(
        candidateSource.year,
        candidateSource.month,
        candidateSource.day,
      );

      if (!candidateDate.isBefore(todayDate)) {
        continue;
      }

      if (lastMetDate == null || candidateDate.isAfter(lastMetDate)) {
        lastMetDate = candidateDate;
        lastSchedule = schedule;
      }
    }

    if (lastSchedule == null || lastMetDate == null) return null;

    final daysSince = todayDate.difference(lastMetDate).inDays;

    return {
      'schedule': lastSchedule,
      'days_since': daysSince,
      'last_met_date': lastMetDate,
    };
  }

  /// 다음 동시 휴무일 조회 (오늘 포함, 최대 90일 이내)
  Future<Map<String, dynamic>?> getNextBothOff(String coupleId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);
    final limitDate = today.add(const Duration(days: 90));
    final limitStr = _formatDate(limitDate);

    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return null;

    final myRaw = await supabase
        .from('schedules')
        .select('date, category')
        .eq('couple_id', coupleId)
        .eq('user_id', currentUserId)
        .gte('date', todayStr)
        .lte('date', limitStr);

    final partnerRaw = await supabase
        .from('schedules')
        .select('date, category')
        .eq('couple_id', coupleId)
        .neq('user_id', currentUserId)
        .gte('date', todayStr)
        .lte('date', limitStr);

    final myCategoriesByDate = <String, List<String?>>{};
    for (final row in (myRaw as List)) {
      final date = row['date'] as String?;
      if (date == null) continue;
      myCategoriesByDate.putIfAbsent(date, () => <String?>[]).add(
        row['category'] as String?,
      );
    }

    final partnerCategoriesByDate = <String, List<String?>>{};
    for (final row in (partnerRaw as List)) {
      final date = row['date'] as String?;
      if (date == null) continue;
      partnerCategoriesByDate.putIfAbsent(date, () => <String?>[]).add(
        row['category'] as String?,
      );
    }

    bool isOffDay(Map<String, List<String?>> byDate, String dateKey) {
      final categories = byDate[dateKey];
      if (categories == null || categories.isEmpty) {
        // 일정이 아예 없으면 쉬는날로 간주
        return true;
      }
      return categories.any(_isOffCategory);
    }

    for (int i = 0; i <= 90; i++) {
      final candidate = today.add(Duration(days: i));
      final key = _formatDate(candidate);
      final mineOff = isOffDay(myCategoriesByDate, key);
      final partnerOff = isOffDay(partnerCategoriesByDate, key);
      if (mineOff && partnerOff) {
        return {'date': candidate, 'days_until': i};
      }
    }

    return null;
  }

  /// 홈 화면 요약 데이터
  Future<Map<String, dynamic>> getHomeSummary(String coupleId) async {
    final results = await Future.wait([
      getDDays(coupleId),
      getTodaySchedules(coupleId),
      getTomorrowSchedules(coupleId),
      getNextDateSchedule(coupleId),
      getLastDateSchedule(coupleId),
      getNextBothOff(coupleId),
    ]);

    return {
      'd_days': results[0],
      'today_schedules': results[1],
      'tomorrow_schedules': results[2],
      'next_date': results[3],
      'last_date': results[4],
      'next_both_off': results[5],
    };
  }

  /// 현재 유저의 coupleId 가져오기
  Future<String?> getCoupleId() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .maybeSingle();
    return profile?['couple_id'] as String?;
  }
}

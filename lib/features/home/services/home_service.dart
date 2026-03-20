import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';

class HomeService {
  /// D-day 정보 + 내 애인 닉네임 조회
  Future<Map<String, dynamic>> getDDays(String coupleId) async {
    final coupleData = await supabase
        .from('couples')
        .select('started_at, user1_id, user2_id')
        .eq('id', coupleId)
        .single();

    final startedAt = coupleData['started_at'] as String?;
    if (startedAt == null) return {};

    final startedDate = DateTime.parse(startedAt);
    final now = DateTime.now();
    final diff = now.difference(startedDate);

    final currentUserId = supabase.auth.currentUser!.id;
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
      'days': diff.inDays,
      'started_at': startedAt,
      'partner_nickname': partnerNickname,
    };
  }

  /// 오늘의 일정 요약
  Future<Map<String, List<Schedule>>> getTodaySchedules(String coupleId) async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];
    final currentUserId = supabase.auth.currentUser!.id;

    // 내 오늘 일정 (단일 일정 + 오늘을 포함하는 다중일 일정)
    final myData = await supabase
        .from('schedules')
        .select()
        .eq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .or('date.eq.$todayStr,and(start_date.lte.$todayStr,end_date.gte.$todayStr)')
        .order('start_time', ascending: true);

    final mySchedules = (myData as List)
        .map((e) => Schedule.fromMap(e))
        .toList();

    // 내 애인 오늘 일정
    final partnerData = await supabase
        .from('schedules')
        .select()
        .neq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .or('date.eq.$todayStr,and(start_date.lte.$todayStr,end_date.gte.$todayStr)')
        .order('start_time', ascending: true);

    final partnerSchedules = (partnerData as List)
        .map((e) => Schedule.fromMap(e))
        .toList();

    return {'mine': mySchedules, 'partner': partnerSchedules};
  }

  /// 내일의 일정 요약
  Future<Map<String, List<Schedule>>> getTomorrowSchedules(
    String coupleId,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = tomorrow.toIso8601String().split('T')[0];
    final currentUserId = supabase.auth.currentUser!.id;

    final myData = await supabase
        .from('schedules')
        .select()
        .eq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .or('date.eq.$tomorrowStr,and(start_date.lte.$tomorrowStr,end_date.gte.$tomorrowStr)')
        .order('start_time', ascending: true);

    final partnerData = await supabase
        .from('schedules')
        .select()
        .neq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .or('date.eq.$tomorrowStr,and(start_date.lte.$tomorrowStr,end_date.gte.$tomorrowStr)')
        .order('start_time', ascending: true);

    return {
      'mine': (myData as List).map((e) => Schedule.fromMap(e)).toList(),
      'partner': (partnerData as List).map((e) => Schedule.fromMap(e)).toList(),
    };
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

  /// 홈 화면 요약 데이터
  Future<Map<String, dynamic>> getHomeSummary(String coupleId) async {
    final dDays = await getDDays(coupleId);
    final todaySchedules = await getTodaySchedules(coupleId);
    final tomorrowSchedules = await getTomorrowSchedules(coupleId);
    final nextDate = await getNextDateSchedule(coupleId);

    return {
      'd_days': dDays,
      'today_schedules': todaySchedules,
      'tomorrow_schedules': tomorrowSchedules,
      'next_date': nextDate,
    };
  }

  /// 현재 유저의 coupleId 가져오기
  Future<String?> getCoupleId() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .maybeSingle();
    return profile?['couple_id'] as String?;
  }
}

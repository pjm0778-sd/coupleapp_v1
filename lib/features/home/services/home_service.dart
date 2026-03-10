import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';

class HomeService {
  /// D-day 정보 조회
  Future<Map<String, dynamic>> getDDays(String coupleId) async {
    final coupleData = await supabase
        .from('couples')
        .select('started_at')
        .eq('id', coupleId)
        .single();

    final startedAt = coupleData['started_at'] as String?;
    if (startedAt == null) return {};

    final startedDate = DateTime.parse(startedAt);
    final now = DateTime.now();
    final diff = now.difference(startedDate);

    return {
      'days': diff.inDays,
      'started_at': startedDate,
    };
  }

  /// 오늘의 일정 요약
  Future<Map<String, List<Schedule>>> getTodaySchedules(
    String coupleId,
  ) async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];
    final currentUserId = supabase.auth.currentUser!.id;

    // 내 오늘 일정
    final myData = await supabase
        .from('schedules')
        .select()
        .eq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .eq('date', todayStr)
        .order('start_time', ascending: true);

    final mySchedules = (myData as List)
        .map((e) => Schedule.fromMap(e))
        .toList();

    // 파트너 오늘 일정
    final partnerData = await supabase
        .from('schedules')
        .select()
        .neq('user_id', currentUserId)
        .eq('couple_id', coupleId)
        .eq('date', todayStr)
        .order('start_time', ascending: true);

    final partnerSchedules = (partnerData as List)
        .map((e) => Schedule.fromMap(e))
        .toList();

    return {
      'mine': mySchedules,
      'partner': partnerSchedules,
    };
  }

  /// 다음 데이트 조회
  Future<Map<String, dynamic>?> getNextDateSchedule(
    String coupleId,
  ) async {
    final now = DateTime.now();

    // 다음 데이트 일정 조회
    final result = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .eq('category', '데이트')
        .gt('date', now.toIso8601String().split('T')[0])
        .order('date', ascending: true)
        .limit(1)
        .maybeSingle();

    if (result == null) return null;

    final schedule = Schedule.fromMap(result);
    final diff = DateTime(schedule.date.year, schedule.date.month, schedule.date.day)
        .difference(now);

    return {
      'schedule': schedule,
      'days_until': diff.inDays,
    };
  }

  /// 홈 화면 요약 데이터
  Future<Map<String, dynamic>> getHomeSummary(String coupleId) async {
    final dDays = await getDDays(coupleId);
    final todaySchedules = await getTodaySchedules(coupleId);
    final nextDate = await getNextDateSchedule(coupleId);

    return {
      'd_days': dDays,
      'today_schedules': todaySchedules,
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

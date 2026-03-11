import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';

enum ScheduleFilter {
  mine,        // 나만
  partner,      // 파트너만
  both,         // 둘 다
}

class ScheduleService {
  /// 해당 월의 커플 전체 일정 가져오기
  Future<List<Schedule>> getMonthSchedules(
    String coupleId,
    DateTime month, {
    ScheduleFilter filter = ScheduleFilter.both,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final currentUserId = supabase.auth.currentUser!.id;

    final query = supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .gte('date', start.toIso8601String().split('T')[0])
        .lte('date', end.toIso8601String().split('T')[0])
        .order('date', ascending: true)
        .order('start_time', ascending: true);

    final data = await switch (filter) {
      case ScheduleFilter.mine =>
        query.neq('user_id', currentUserId),
      case ScheduleFilter.partner =>
        query.neq('user_id', currentUserId),
      case ScheduleFilter.both => query,
    };

    return (data as List).map((e) => Schedule.fromMap(e)).toList();
  }

  /// 특정 날짜의 일정 가져오기
  Future<List<Schedule>> getDateSchedules(
    String coupleId,
    DateTime date, {
    ScheduleFilter filter = ScheduleFilter.both,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final currentUserId = supabase.auth.currentUser!.id;

    final query = supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .eq('date', dateStr)
        .order('start_time', ascending: true);

    final data = await switch (filter) {
      case ScheduleFilter.mine =>
        query.neq('user_id', currentUserId),
      case ScheduleFilter.partner =>
        query.neq('user_id', currentUserId),
      case ScheduleFilter.both => query,
    };

    return (data as List).map((e) => Schedule.fromMap(e)).toList();
  }

  /// 일정 상세 조회
  Future<Schedule?> getScheduleById(String id) async {
    final data = await supabase
        .from('schedules')
        .select()
        .eq('id', id)
        .single();
    if (data == null) return null;
    return Schedule.fromMap(data);
  }

  /// 일정 추가
  Future<void> addSchedule(Schedule schedule) async {
    await supabase.from('schedules').insert(schedule.toMap());
  }

  /// 일정 삭제
  Future<void> deleteSchedule(String id) async {
    await supabase.from('schedules').delete().eq('id', id);
  }

  /// 일정 수정
  Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    await supabase.from('schedules').update(data).eq('id', id);
  }

  /// 해당 월의 커플 전체 일정 삭제
  Future<void> deleteMonthSchedules(String coupleId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    await supabase
        .from('schedules')
        .delete()
        .eq('couple_id', coupleId)
        .gte('date', start.toIso8601String().split('T')[0])
        .lte('date', end.toIso8601String().split('T')[0]);
  }

  /// 현재 유저의 coupleId 가져오기
  Future<String?> getCoupleId() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .single();
    return profile['couple_id'] as String?;
  }

  /// 현재 유저 ID
  String get currentUserId => supabase.auth.currentUser!.id;

  /// 일정이 현재 유저의 것인지 확인
  bool isMine(Schedule schedule) => schedule.userId == currentUserId;
}

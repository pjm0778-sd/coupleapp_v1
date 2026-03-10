import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';

class ScheduleService {
  /// 해당 월의 커플 전체 일정 가져오기
  Future<List<Schedule>> getMonthSchedules(String coupleId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final data = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .gte('date', start.toIso8601String().split('T')[0])
        .lte('date', end.toIso8601String().split('T')[0]);

    return (data as List).map((e) => Schedule.fromMap(e)).toList();
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
}

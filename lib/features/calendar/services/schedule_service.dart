import 'dart:math';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';
import '../../../shared/models/repeat_pattern.dart';

enum ScheduleFilter {
  mine,        // ?섎쭔
  partner,      // ?뚰듃?덈쭔
  both,         // ????
}

class ScheduleService {
  /// ?대떦 ?붿쓽 而ㅽ뵆 ?꾩껜 ?쇱젙 媛?몄삤湲?
  Future<List<Schedule>> getMonthSchedules(
    String coupleId,
    DateTime month, {
    ScheduleFilter filter = ScheduleFilter.both,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final currentUserId = supabase.auth.currentUser!.id;

    dynamic data;
    switch (filter) {
      case ScheduleFilter.mine:
        data = await supabase
            .from('schedules')
            .select()
            .eq('couple_id', coupleId)
            .eq('user_id', currentUserId)
            .gte('date', start.toIso8601String().split('T')[0])
            .lte('date', end.toIso8601String().split('T')[0])
            .order('date', ascending: true)
            .order('start_time', ascending: true);
        break;
      case ScheduleFilter.partner:
        data = await supabase
            .from('schedules')
            .select()
            .eq('couple_id', coupleId)
            .not('user_id', 'eq', currentUserId)
            .gte('date', start.toIso8601String().split('T')[0])
            .lte('date', end.toIso8601String().split('T')[0])
            .order('date', ascending: true)
            .order('start_time', ascending: true);
        break;
      case ScheduleFilter.both:
        data = await supabase
            .from('schedules')
            .select()
            .eq('couple_id', coupleId)
            .gte('date', start.toIso8601String().split('T')[0])
            .lte('date', end.toIso8601String().split('T')[0])
            .order('date', ascending: true)
            .order('start_time', ascending: true);
        break;
    }

    return (data as List).map((e) => Schedule.fromMap(e)).toList();
  }

  /// ?뱀젙 ?좎쭨???쇱젙 媛?몄삤湲?
  Future<List<Schedule>> getDateSchedules(
    String coupleId,
    DateTime date, {
    ScheduleFilter filter = ScheduleFilter.both,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final currentUserId = supabase.auth.currentUser!.id;

    dynamic data;
    switch (filter) {
      case ScheduleFilter.mine:
        data = await supabase
            .from('schedules')
            .select()
            .eq('couple_id', coupleId)
            .eq('user_id', currentUserId)
            .eq('date', dateStr)
            .order('start_time', ascending: true);
        break;
      case ScheduleFilter.partner:
        data = await supabase
            .from('schedules')
            .select()
            .eq('couple_id', coupleId)
            .not('user_id', 'eq', currentUserId)
            .eq('date', dateStr)
            .order('start_time', ascending: true);
        break;
      case ScheduleFilter.both:
        data = await supabase
            .from('schedules')
            .select()
            .eq('couple_id', coupleId)
            .eq('date', dateStr)
            .order('start_time', ascending: true);
        break;
    }

    return (data as List).map((e) => Schedule.fromMap(e)).toList();
  }

  /// ?쇱젙 ?곸꽭 議고쉶
  Future<Schedule?> getScheduleById(String id) async {
    final data = await supabase
        .from('schedules')
        .select()
        .eq('id', id)
        .single();
    if (data == null) return null;
    return Schedule.fromMap(data);
  }

  /// ?쇱젙 異붽? (諛섎났 ?⑦꽩???덉쑝硫??먮룞?쇰줈 ?щ윭 ?좎쭨???앹꽦)
  Future<void> addSchedule(Schedule schedule) async {
    final repeatMap = schedule.repeatPattern;

    if (repeatMap == null) {
      // ?⑥씪 ?쇱젙
      await supabase.from('schedules').insert(schedule.toMap());
      return;
    }

    // 諛섎났 ?쇱젙: 洹몃９ ID濡?臾띔린
    final rp = RepeatPattern.fromMap(repeatMap);
    final groupId = _generateGroupId();

    final dates = _generateRepeatDates(
      pattern: rp,
      startDate: schedule.date,
      maxMonths: 12, // 理쒕? 12媛쒖썡移??앹꽦
    );

    if (dates.isEmpty) {
      // ?좎쭨 ?앹꽦 ?ㅽ뙣 ???⑥씪 ???
      await supabase.from('schedules').insert(schedule.toMap());
      return;
    }

    // bulk insert
    final rows = dates.map((d) {
      final map = schedule.toMap();
      map['date'] = d.toIso8601String().split('T')[0];
      map['repeat_group_id'] = groupId;
      return map;
    }).toList();

    // Supabase insert??list 吏??
    await supabase.from('schedules').insert(rows);
  }

  /// 諛섎났 ?쇱젙 洹몃９ ?꾩껜 ??젣
  Future<void> deleteRepeatGroup(String groupId) async {
    await supabase
        .from('schedules')
        .delete()
        .eq('repeat_group_id', groupId);
  }

  /// ?뱀젙 ?좎쭨 ?댄썑 諛섎났 ?쇱젙 ??젣
  Future<void> deleteRepeatGroupFrom(String groupId, DateTime from) async {
    await supabase
        .from('schedules')
        .delete()
        .eq('repeat_group_id', groupId)
        .gte('date', from.toIso8601String().split('T')[0]);
  }

  /// 諛섎났 ?⑦꽩???곕씪 ?좎쭨 紐⑸줉 ?앹꽦
  List<DateTime> _generateRepeatDates({
    required RepeatPattern pattern,
    required DateTime startDate,
    int maxMonths = 12,
  }) {
    final endDate = pattern.endDate ??
        DateTime(startDate.year, startDate.month + maxMonths, startDate.day);
    final dates = <DateTime>[];

    switch (pattern.type) {
      case 'daily':
        var d = startDate;
        final interval = pattern.interval ?? 1;
        while (!d.isAfter(endDate)) {
          dates.add(d);
          d = d.add(Duration(days: interval));
          if (dates.length > 500) break; // ?덉쟾?μ튂
        }

      case 'weekly':
        if (pattern.days == null || pattern.days!.isEmpty) break;
        var d = startDate;
        while (!d.isAfter(endDate)) {
          if (pattern.days!.contains(d.weekday)) {
            dates.add(d);
          }
          d = d.add(const Duration(days: 1));
          if (dates.length > 500) break;
        }

      case 'monthly':
        var year = startDate.year;
        var month = startDate.month;
        final day = startDate.day;
        while (true) {
          final lastDay = DateTime(year, month + 1, 0).day;
          final d = DateTime(year, month, min(day, lastDay));
          if (d.isAfter(endDate)) break;
          if (!d.isBefore(startDate)) dates.add(d);
          month++;
          if (month > 12) { month = 1; year++; }
          if (dates.length > 120) break;
        }

      case 'yearly':
        var year = startDate.year;
        while (true) {
          final d = DateTime(year, startDate.month, startDate.day);
          if (d.isAfter(endDate)) break;
          if (!d.isBefore(startDate)) dates.add(d);
          year++;
          if (dates.length > 20) break;
        }

      case '二쇰쭚':
        var d = startDate;
        while (!d.isAfter(endDate)) {
          if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
            dates.add(d);
          }
          d = d.add(const Duration(days: 1));
          if (dates.length > 500) break;
        }

      case '?됱씪':
        var d = startDate;
        while (!d.isAfter(endDate)) {
          if (d.weekday >= DateTime.monday && d.weekday <= DateTime.friday) {
            dates.add(d);
          }
          d = d.add(const Duration(days: 1));
          if (dates.length > 500) break;
        }
    }

    return dates;
  }

  String _generateGroupId() {
    final rand = Random().nextInt(999999999);
    return 'repeat_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  /// ?쇱젙 ??젣
  Future<void> deleteSchedule(String id) async {
    await supabase.from('schedules').delete().eq('id', id);
  }

  /// ?쇱젙 ?섏젙
  Future<void> updateSchedule(String id, Map<String, dynamic> data) async {
    await supabase.from('schedules').update(data).eq('id', id);
  }

  /// ?대떦 ?붿쓽 而ㅽ뵆 ?꾩껜 ?쇱젙 ??젣
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

  /// ?대떦 ?붿쓽 蹂몄씤 ?쇱젙 ?꾩껜 ??젣
  Future<int> deleteMyMonthSchedules(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final currentUserId = supabase.auth.currentUser!.id;

    final data = await supabase
        .from('schedules')
        .delete()
        .eq('user_id', currentUserId)
        .gte('date', start.toIso8601String().split('T')[0])
        .lte('date', end.toIso8601String().split('T')[0]);

    return data.count ?? 0;
  }

  /// ?꾩옱 ?좎???coupleId 媛?몄삤湲?
  Future<String?> getCoupleId() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from('profiles')
        .select('couple_id')
        .eq('id', userId)
        .maybeSingle();
    return profile?['couple_id'] as String?;
  }

  /// ?꾩옱 ?좎? ID
  String get currentUserId => supabase.auth.currentUser!.id;

  /// ?쇱젙???꾩옱 ?좎???寃껋씤吏 ?뺤씤
  bool isMine(Schedule schedule) => schedule.userId == currentUserId;
}

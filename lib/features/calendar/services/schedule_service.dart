import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/schedule.dart';
import '../../../shared/models/repeat_pattern.dart';

class ScheduleService {
  /// 해당 월의 커플 전체 일정 가져오기 (필터 없음 — 통합 달력)
  Future<List<Schedule>> getMonthSchedules(
    String coupleId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final data = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .gte('date', start.toIso8601String().split('T')[0])
        .lte('date', end.toIso8601String().split('T')[0])
        .order('date', ascending: true)
        .order('start_time', ascending: true);

    return (data as List).map((e) => Schedule.fromMap(e)).toList();
  }

  /// 특정 날짜의 일정 가져오기
  Future<List<Schedule>> getDateSchedules(
    String coupleId,
    DateTime date,
  ) async {
    final dateStr = date.toIso8601String().split('T')[0];

    final data = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .eq('date', dateStr)
        .order('start_time', ascending: true);

    return (data as List).map((e) => Schedule.fromMap(e)).toList();
  }

  /// 우리(couple) → 내(me) → 파트너(partner) 순 정렬.
  /// 같은 그룹 내에서는 시작 시간 오름차순, 시간 없으면 맨 뒤.
  List<Schedule> sortByOwner(List<Schedule> schedules, String myUserId) {
    return [...schedules]..sort((a, b) {
      final oa = _ownerOrder(a, myUserId);
      final ob = _ownerOrder(b, myUserId);
      if (oa != ob) return oa.compareTo(ob);
      final ta = a.startTime;
      final tb = b.startTime;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return (ta.hour * 60 + ta.minute) - (tb.hour * 60 + tb.minute);
    });
  }

  int _ownerOrder(Schedule s, String myUserId) {
    if (s.isAnniversary) return 0; // 기념일 최상단
    if (s.ownerType == 'couple') return 1;
    if (s.userId == myUserId) return 2;
    return 3; // 파트너
  }

  /// 일정 상세 조회
  Future<Schedule?> getScheduleById(String id) async {
    final data = await supabase
        .from('schedules')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return Schedule.fromMap(data);
  }

  /// 일정 추가 (반복 패턴이 있으면 자동으로 여러 날짜에 생성)
  Future<void> addSchedule(Schedule schedule) async {
    final repeatMap = schedule.repeatPattern;

    if (repeatMap == null) {
      // 단일 일정
      await supabase.from('schedules').insert(schedule.toMap());
      return;
    }

    // 반복 설정: 그룹 ID로 묶기
    final rp = RepeatPattern.fromMap(repeatMap);
    final groupId = _generateGroupId();

    final dates = _generateRepeatDates(
      pattern: rp,
      startDate: schedule.date,
      maxMonths: 12, // 최대 12개월치 생성
    );

    if (dates.isEmpty) {
      // 날짜 생성 실패 시 단일 저장
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

    // Supabase insert는 list 지원
    await supabase.from('schedules').insert(rows);
  }

  /// 반복 일정 그룹 전체 삭제
  Future<void> deleteRepeatGroup(String groupId) async {
    await supabase.from('schedules').delete().eq('repeat_group_id', groupId);
  }

  /// 특정 날짜 이후 반복 일정 삭제
  Future<void> deleteRepeatGroupFrom(String groupId, DateTime from) async {
    await supabase
        .from('schedules')
        .delete()
        .eq('repeat_group_id', groupId)
        .gte('date', from.toIso8601String().split('T')[0]);
  }

  /// 반복 패턴에 따라 날짜 목록 생성
  List<DateTime> _generateRepeatDates({
    required RepeatPattern pattern,
    required DateTime startDate,
    int maxMonths = 12,
  }) {
    final endDate =
        pattern.endDate ??
        DateTime(startDate.year, startDate.month + maxMonths, startDate.day);
    final dates = <DateTime>[];

    switch (pattern.type) {
      case 'daily':
        var d = startDate;
        final interval = pattern.interval ?? 1;
        while (!d.isAfter(endDate)) {
          dates.add(d);
          d = d.add(Duration(days: interval));
          if (dates.length > 500) break; // 안전장치
        }
        break;

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
        break;

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
          if (month > 12) {
            month = 1;
            year++;
          }
          if (dates.length > 120) break;
        }
        break;

      case 'yearly':
        var year = startDate.year;
        while (true) {
          final d = DateTime(year, startDate.month, startDate.day);
          if (d.isAfter(endDate)) break;
          if (!d.isBefore(startDate)) dates.add(d);
          year++;
          if (dates.length > 20) break;
        }
        break;

      case '주말':
        var d = startDate;
        while (!d.isAfter(endDate)) {
          if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
            dates.add(d);
          }
          d = d.add(const Duration(days: 1));
          if (dates.length > 500) break;
        }
        break;

      case '평일':
        var d = startDate;
        while (!d.isAfter(endDate)) {
          if (d.weekday >= DateTime.monday && d.weekday <= DateTime.friday) {
            dates.add(d);
          }
          d = d.add(const Duration(days: 1));
          if (dates.length > 500) break;
        }
        break;
    }

    return dates;
  }

  String _generateGroupId() {
    final rand = Random().nextInt(999999999);
    return 'repeat_${DateTime.now().millisecondsSinceEpoch}_$rand';
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

  /// 해당 월의 본인 일정 전체 삭제
  Future<int> deleteMyMonthSchedules(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);
      final currentUserId = supabase.auth.currentUser!.id;

      final data = await supabase
          .from('schedules')
          .delete()
          .eq('user_id', currentUserId)
          .gte('date', start.toIso8601String().split('T')[0])
          .lte('date', end.toIso8601String().split('T')[0])
          .select();
      return (data as List).length;
    } catch (e) {
      debugPrint('deleteMyMonthSchedules error: $e');
      // 삭제 과정에서 에러가 나더라도 실제 쿼리는 수행되었을 수 있으므로
      // 예외를 밖으로 던져서 UI에서 처리하게 하되, 로그를 남깁니다.
      rethrow;
    }
  }

  /// 해당 월의 본인 OCR 일정만 삭제 (구글 캘린더 연동 일정 제외)
  Future<int> deleteMyOcrMonthSchedules(
    DateTime month,
    String coupleId,
  ) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);
      final currentUserId = supabase.auth.currentUser!.id;

      final data = await supabase
          .from('schedules')
          .delete()
          .eq('couple_id', coupleId)
          .eq('user_id', currentUserId)
          .eq('is_ocr', true)
          .eq('is_google_calendar', false)
          .gte('date', start.toIso8601String().split('T')[0])
          .lte('date', end.toIso8601String().split('T')[0])
          .select();
      return (data as List).length;
    } catch (e) {
      debugPrint('deleteMyOcrMonthSchedules error: $e');
      rethrow;
    }
  }

  /// 해당 월의 파트너 OCR 일정만 삭제 (구글 캘린더 연동 일정 제외)
  Future<int> deletePartnerOcrMonthSchedules(
    DateTime month,
    String partnerId,
    String coupleId,
  ) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);

      final data = await supabase
          .from('schedules')
          .delete()
          .eq('couple_id', coupleId)
          .eq('user_id', partnerId)
          .eq('is_ocr', true)
          .eq('is_google_calendar', false)
          .gte('date', start.toIso8601String().split('T')[0])
          .lte('date', end.toIso8601String().split('T')[0])
          .select();
      return (data as List).length;
    } catch (e) {
      debugPrint('deletePartnerOcrMonthSchedules error: $e');
      rethrow;
    }
  }

  /// 해당 월의 본인 구글 캘린더 연동 일정 삭제
  Future<int> deleteMyGoogleCalendarMonthSchedules(
    DateTime month,
    String coupleId,
  ) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);
      final currentUserId = supabase.auth.currentUser!.id;

      final data = await supabase
          .from('schedules')
          .delete()
          .eq('couple_id', coupleId)
          .eq('user_id', currentUserId)
          .eq('is_google_calendar', true)
          .gte('date', start.toIso8601String().split('T')[0])
          .lte('date', end.toIso8601String().split('T')[0])
          .select();
      return (data as List).length;
    } catch (e) {
      debugPrint('deleteMyGoogleCalendarMonthSchedules error: $e');
      rethrow;
    }
  }

  /// 해당 월의 파트너 구글 캘린더 연동 일정 삭제
  Future<int> deletePartnerGoogleCalendarMonthSchedules(
    DateTime month,
    String partnerId,
    String coupleId,
  ) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0);

      final data = await supabase
          .from('schedules')
          .delete()
          .eq('couple_id', coupleId)
          .eq('user_id', partnerId)
          .eq('is_google_calendar', true)
          .gte('date', start.toIso8601String().split('T')[0])
          .lte('date', end.toIso8601String().split('T')[0])
          .select();
      return (data as List).length;
    } catch (e) {
      debugPrint('deletePartnerGoogleCalendarMonthSchedules error: $e');
      rethrow;
    }
  }

  /// 위치 정보가 있는 커플 일정 전체 조회 (지도용)
  Future<List<Schedule>> getSchedulesWithLocation(String coupleId) async {
    final data = await supabase
        .from('schedules')
        .select()
        .eq('couple_id', coupleId)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .order('date', ascending: false);
    return (data as List).map((e) => Schedule.fromMap(e)).toList();
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

  /// 현재 유저 ID
  String get currentUserId => supabase.auth.currentUser!.id;

  /// 일정이 현재 유저의 것인지 확인
  bool isMine(Schedule schedule) => schedule.userId == currentUserId;
}

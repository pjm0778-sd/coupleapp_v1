import '../../core/models/holiday.dart';
import '../../../core/supabase_client.dart';

class HolidayService {
  static final HolidayService _instance = HolidayService._internal();
  factory HolidayService() => _instance;
  HolidayService._internal();

  // 대한민국 공휴일 (2026년 기준)
  static final List<Holiday> _koreaHolidays2026 = [
    Holiday(date: DateTime(2026, 1, 1), name: '신정', isNationwide: true),
    Holiday(date: DateTime(2026, 3, 1), name: '삼일절', isNationwide: true),
    Holiday(date: DateTime(2026, 5, 5), name: '어린이날', isNationwide: true),
    Holiday(date: DateTime(2026, 6, 6), name: '현충일', isNationwide: true),
    Holiday(date: DateTime(2026, 8, 15), name: '광복절', isNationwide: true),
    Holiday(date: DateTime(2026, 9, 15), name: '추석', isNationwide: false),
    Holiday(date: DateTime(2026, 9, 16), name: '추석 다음날', isNationwide: false),
    Holiday(date: DateTime(2026, 10, 3), name: '개천절', isNationwide: true),
    Holiday(date: DateTime(2026, 10, 9), name: '한글날', isNationwide: true),
    Holiday(date: DateTime(2026, 12, 25), name: '성탄일', isNationwide: true),
  ];

  // 근로자의 날 (5월 1일)
  static final Holiday _laborDay2026 = Holiday(
    date: DateTime(2026, 5, 1),
    name: '근로자의 날',
    isNationwide: true,
  );

  /// 특정 연도의 모든 공휴일 조회
  List<Holiday> getHolidaysForYear(int year) {
    return [
      ..._koreaHolidays2026.where((h) => h.date.year == year),
      if (year == 2026) _laborDay2026,
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// 특정 날짜가 공휴일인지 확인
  bool isHoliday(DateTime date) {
    final yearHolidays = getHolidaysForYear(date.year);
    return yearHolidays.any((h) =>
      h.date.year == date.year &&
      h.date.month == date.month &&
      h.date.day == date.day
    );
  }
}

import 'package:flutter/material.dart';

enum HolidayType {
  publicHoliday, // 법정 공휴일 (빨간색)
  coupleAnniversary, // 커플 기념일 (핑크색)
}

class Holiday {
  final String name;
  final String emoji;
  final HolidayType type;

  const Holiday({required this.name, required this.emoji, required this.type});

  Color get color {
    switch (type) {
      case HolidayType.publicHoliday:
        return const Color(0xFFE53935);
      case HolidayType.coupleAnniversary:
        return const Color(0xFFE91E63);
    }
  }
}

class HolidayService {
  static final HolidayService _instance = HolidayService._internal();
  factory HolidayService() => _instance;
  HolidayService._internal();

  // ───────────────────────────────────────────────────
  // 커플 기념일 (매년 반복 – month/day 기준)
  // ───────────────────────────────────────────────────
  static const List<({int month, int day, String name, String emoji})>
  _coupleAnniversaries = [
    (month: 1, day: 14, name: '다이어리데이', emoji: '📓'),
    (month: 2, day: 14, name: '발렌타인데이', emoji: '🍫'),
    (month: 3, day: 14, name: '화이트데이', emoji: '🍬'),
    (month: 4, day: 14, name: '블랙데이', emoji: '🍜'),
    (month: 5, day: 14, name: '로즈데이', emoji: '🌹'),
    (month: 5, day: 1, name: '근로자의 날', emoji: '👷'),
    (month: 6, day: 14, name: '키스데이', emoji: '💋'),
    (month: 7, day: 14, name: '실버데이', emoji: '🥈'),
    (month: 8, day: 14, name: '그린데이', emoji: '🍃'),
    (month: 9, day: 14, name: '포토데이', emoji: '📸'),
    (month: 10, day: 14, name: '와인데이', emoji: '🍷'),
    (month: 10, day: 31, name: '핼러윈', emoji: '🎃'),
    (month: 11, day: 11, name: '빼빼로데이', emoji: '🍫'),
    (month: 11, day: 14, name: '무비데이', emoji: '🎬'),
    (month: 12, day: 14, name: '허그데이', emoji: '🤗'),
    (month: 12, day: 24, name: '크리스마스 이브', emoji: '🎄'),
    (month: 12, day: 25, name: '크리스마스', emoji: '🎅'),
  ];

  // ───────────────────────────────────────────────────
  // 한국 법정 공휴일 (2025~2030)
  // 음력 기반 공휴일은 미리 계산된 날짜로 지정
  // ───────────────────────────────────────────────────
  static const Map<String, String> _publicHolidays = {
    // ── 고정 공휴일 (매년 동일) ──
    // 신정
    '0101': '신정',
    // 삼일절
    '0301': '삼일절',
    // 어린이날
    '0505': '어린이날',
    // 현충일
    '0606': '현충일',
    // 광복절
    '0815': '광복절',
    // 개천절
    '1003': '개천절',
    // 한글날
    '1009': '한글날',
    // 크리스마스
    '1225': '크리스마스',

    // ── 2025년 음력 공휴일 ──
    '20250128': '설날 전날',
    '20250129': '설날',
    '20250130': '설날 다음날',
    '20250505': '어린이날 / 부처님 오신 날', // 겹침 처리
    '20251003': '추석 전날',
    '20251004': '추석',
    '20251005': '추석 다음날',
    '20251006': '대체공휴일',

    // ── 2026년 음력 공휴일 ──
    '20260216': '설날 전날',
    '20260217': '설날',
    '20260218': '설날 다음날',
    '20260524': '부처님 오신 날',
    '20260924': '추석 전날',
    '20260925': '추석',
    '20260926': '추석 다음날',

    // ── 2027년 음력 공휴일 ──
    '20270205': '설날 전날',
    '20270206': '설날',
    '20270207': '설날 다음날',
    '20270513': '부처님 오신 날',
    '20271014': '추석 전날',
    '20271015': '추석',
    '20271016': '추석 다음날',

    // ── 2028년 음력 공휴일 ──
    '20280126': '설날 전날',
    '20280127': '설날',
    '20280128': '설날 다음날',
    '20280502': '부처님 오신 날',
    '20281002': '추석 전날',
    '20281003': '추석',
    '20281004': '추석 다음날',

    // ── 2029년 음력 공휴일 ──
    '20290212': '설날 전날',
    '20290213': '설날',
    '20290214': '설날 다음날',
    '20290520': '부처님 오신 날',
    '20290921': '추석 전날',
    '20290922': '추석',
    '20290923': '추석 다음날',

    // ── 2030년 음력 공휴일 ──
    '20300202': '설날 전날',
    '20300203': '설날',
    '20300204': '설날 다음날',
    '20300509': '부처님 오신 날',
    '20301010': '추석 전날',
    '20301011': '추석',
    '20301012': '추석 다음날',
  };

  // ───────────────────────────────────────────────────
  // 공개 API
  // ───────────────────────────────────────────────────

  /// 해당 날짜의 공휴일/기념일 목록 반환
  List<Holiday> getHolidays(DateTime date) {
    final result = <Holiday>[];

    // 1. 법정 공휴일 확인 (연도 포함 키 먼저, 고정키 나중)
    final yearKey =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final fixedKey =
        '${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

    if (_publicHolidays.containsKey(yearKey)) {
      result.add(
        Holiday(
          name: _publicHolidays[yearKey]!,
          emoji: '🇰🇷',
          type: HolidayType.publicHoliday,
        ),
      );
    } else if (_publicHolidays.containsKey(fixedKey)) {
      result.add(
        Holiday(
          name: _publicHolidays[fixedKey]!,
          emoji: '🇰🇷',
          type: HolidayType.publicHoliday,
        ),
      );
    }

    // 2. 커플 기념일 확인 (매년 반복)
    for (final ann in _coupleAnniversaries) {
      if (ann.month == date.month && ann.day == date.day) {
        result.add(
          Holiday(
            name: ann.name,
            emoji: ann.emoji,
            type: HolidayType.coupleAnniversary,
          ),
        );
      }
    }

    return result;
  }

  /// 해당 날짜가 공휴일이나 기념일인지 여부
  bool hasHoliday(DateTime date) => getHolidays(date).isNotEmpty;

  /// 해당 월의 전체 공휴일/기념일 맵 반환
  Map<DateTime, List<Holiday>> getMonthHolidays(DateTime month) {
    final result = <DateTime, List<Holiday>>{};
    final lastDay = DateTime(month.year, month.month + 1, 0).day;

    for (int d = 1; d <= lastDay; d++) {
      final date = DateTime(month.year, month.month, d);
      final holidays = getHolidays(date);
      if (holidays.isNotEmpty) {
        result[date] = holidays;
      }
    }
    return result;
  }

  /// 대표 공휴일 이름 (첫 번째 항목)
  String? getPrimaryHolidayName(DateTime date) {
    final holidays = getHolidays(date);
    if (holidays.isEmpty) return null;
    return '${holidays.first.emoji} ${holidays.first.name}';
  }

  /// 공휴일 여부 (법정 공휴일만)
  bool isPublicHoliday(DateTime date) {
    return getHolidays(date).any((h) => h.type == HolidayType.publicHoliday);
  }
}

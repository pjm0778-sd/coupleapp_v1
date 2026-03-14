class RepeatPattern {
  final String type; // daily, weekly, monthly, yearly
  final List<int>? days; // 요일 (1=월, 7=일)
  final DateTime? startDate;
  final DateTime? endDate;
  final int? interval; // 반복 간격

  RepeatPattern({
    required this.type,
    this.days,
    this.startDate,
    this.endDate,
    this.interval = 1,
  });

  factory RepeatPattern.fromMap(Map<String, dynamic> map) => RepeatPattern(
    type: map['type'] as String,
    days: (map['days'] as List<dynamic>?)?.map((e) => e as int).toList(),
    startDate: map['start_date'] != null
        ? DateTime.parse(map['start_date'] as String)
        : null,
    endDate: map['end_date'] != null
        ? DateTime.parse(map['end_date'] as String)
        : null,
    interval: map['interval'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'type': type,
    'days': days,
    'start_date': startDate?.toIso8601String().split('T')[0],
    'end_date': endDate?.toIso8601String().split('T')[0],
    'interval': interval,
  };

  /// 지정된 날짜가 반복 패턴에 포함되는지 확인
  bool includesDate(DateTime date) {
    switch (type) {
      case 'daily':
        if (startDate != null && date.isBefore(startDate!)) return false;
        if (endDate != null && date.isAfter(endDate!)) return false;
        if (interval == null || interval == 1) return true;
        return date.difference(startDate!).inDays % interval! == 0;

      case 'weekly':
        if (days == null) return false;
        return days!.contains(date.weekday);

      case 'monthly':
        if (startDate != null && date.isBefore(startDate!)) return false;
        if (endDate != null && date.isAfter(endDate!)) return false;
        return date.day == startDate!.day;

      case 'yearly':
        if (startDate != null) {
          final monthDate = DateTime(
            date.year,
            startDate!.month,
            startDate!.day,
          );
          return date.isAtSameMomentAs(monthDate);
        }
        return false;

      case '주말':
        return date.weekday == 6 || date.weekday == 7;
      case '평일':
        return date.weekday >= 1 && date.weekday <= 5;
      default:
        return false;
    }
  }

  /// 반복 패턴 표시 이름
  String get displayName {
    switch (type) {
      case 'daily':
        return '매일';
      case 'weekly':
        if (days != null && days!.isNotEmpty) {
          final dayNames = ['월', '화', '수', '목', '금', '토', '일'];
          final selectedDays = days!.map((d) => dayNames[d - 1]).join(', ');
          return '매주 $selectedDays';
        }
        return '매주';
      case 'monthly':
        return '매월';
      case 'yearly':
        return '매년';
      case '주말':
        return '주말마다';
      case '평일':
        return '평일마다';
      default:
        return '반복 없음';
    }
  }
}

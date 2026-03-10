class AnniversarySetting {
  final String id;
  final String coupleId;
  final String type; // '100일', '1년', '화이트데이', '발렌타인', '크리스마스', '사용자정의'
  final String? customName;
  final int? customMonth;
  final int? customDay;
  final bool isEnabled;
  final List<int> reminderDays; // 알림 기간 (일)

  AnniversarySetting({
    required this.id,
    required this.coupleId,
    required this.type,
    this.customName,
    this.customMonth,
    this.customDay,
    this.isEnabled = true,
    this.reminderDays = const [7, 1],
  });

  factory AnniversarySetting.fromMap(Map<String, dynamic> map) => AnniversarySetting(
        id: map['id'] as String,
        coupleId: map['couple_id'] as String,
        type: map['anniversary_type'] as String,
        customName: map['custom_name'] as String?,
        customMonth: map['custom_month'] as int?,
        customDay: map['custom_day'] as int?,
        isEnabled: map['is_enabled'] as bool? ?? true,
        reminderDays: (map['reminder_days'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [7, 1],
      );

  Map<String, dynamic> toMap() => {
        'couple_id': coupleId,
        'anniversary_type': type,
        'custom_name': customName,
        'custom_month': customMonth,
        'custom_day': customDay,
        'is_enabled': isEnabled,
        'reminder_days': reminderDays,
      };

  /// 기념일 날짜 계산 (현재 연도 기준)
  DateTime? getDateForYear(int year) {
    switch (type) {
      case '100일':
      case '1년':
        // started_at 기준으로 계산 (HomeService에서 처리)
        return null;
      case '화이트데이':
        return DateTime(year, 3, 14);
      case '발렌타인':
        return DateTime(year, 2, 14);
      case '크리스마스':
        return DateTime(year, 12, 25);
      case '사용자정의':
        if (customMonth != null && customDay != null) {
          return DateTime(year, customMonth!, customDay!);
        }
        return null;
      default:
        return null;
    }
  }

  /// 기념일 표시 이름
  String get displayName {
    switch (type) {
      case '100일':
        return '100일';
      case '1년':
        return '1주년';
      case '화이트데이':
        return '화이트데이';
      case '발렌타인':
        return '발렌타인데이';
      case '크리스마스':
        return '크리스마스';
      case '사용자정의':
        return customName ?? '기념일';
      default:
        return '기념일';
    }
  }
}

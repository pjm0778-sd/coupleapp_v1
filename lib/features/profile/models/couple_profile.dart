import 'shift_time.dart';

/// 거리 유형 — DB 값: 'same_city' | 'near' | 'long_distance'
enum DistanceType {
  sameCity('same_city'),
  near('near'),
  longDistance('long_distance');

  const DistanceType(this.value);
  final String value;

  static DistanceType fromValue(String value) =>
      DistanceType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => DistanceType.sameCity,
      );
}

/// 근무 유형 — DB 값: 'shift_3' | 'shift_2' | 'office' | 'other'
enum WorkPatternType {
  shift3('shift_3'),
  shift2('shift_2'),
  office('office'),
  other('other');

  const WorkPatternType(this.value);
  final String value;

  static WorkPatternType fromValue(String value) =>
      WorkPatternType.values.firstWhere(
        (e) => e.value == value,
        orElse: () => WorkPatternType.office,
      );
}

class CoupleProfile {
  // [GAP-FIX] 추가된 identity 필드
  final String? id;
  final String? userId;
  final String? coupleId;
  final String? nickname;
  final DateTime? coupleStartDate;

  final String coupleType; // 'together' | 'distance'
  final String distanceType; // 'same_city' | 'near' | 'long_distance'
  final String? myCity;
  final String? myStation;
  final String? partnerCity;
  final String? partnerStation;
  final String workPattern; // 'shift_3' | 'shift_2' | 'office' | 'other'

  // [GAP-FIX] 타입드 ShiftTime 리스트 (직렬화는 하위 호환 유지)
  final List<ShiftTime> shiftTimes;

  final int notifyMinutesBefore;
  final bool hasCar;
  final bool onboardingCompleted;

  const CoupleProfile({
    this.id,
    this.userId,
    this.coupleId,
    this.nickname,
    this.coupleStartDate,
    this.coupleType = 'distance',
    required this.distanceType,
    this.myCity,
    this.myStation,
    this.partnerCity,
    this.partnerStation,
    required this.workPattern,
    required this.shiftTimes,
    this.notifyMinutesBefore = 30,
    this.hasCar = false,
    this.onboardingCompleted = false,
  });

  // 파트너 연결 여부
  bool get isConnected => coupleId != null;

  bool get isLongDistance => distanceType == 'long_distance';
  bool get hasShiftWork =>
      workPattern == 'shift_3' || workPattern == 'shift_2';
  bool get hasTransportInfo =>
      isLongDistance && myStation != null && partnerStation != null;
  bool get hasNightShift => shiftTimes.any(
    (s) => s.shiftType == 'N' || s.shiftType == 'night',
  );

  /// Supabase Map 에서 생성 — shift_times 는 List<Map> 형태로 수신
  factory CoupleProfile.fromMap(Map<String, dynamic> map) {
    final rawShifts = map['shift_times'];
    final shifts = rawShifts is List
        ? rawShifts
            .cast<Map<String, dynamic>>()
            .map(ShiftTime.fromMap)
            .toList()
        : <ShiftTime>[];

    DateTime? coupleStartDate;
    if (map['couple_start_date'] != null) {
      coupleStartDate = DateTime.tryParse(map['couple_start_date'] as String);
    }

    return CoupleProfile(
      id: map['id'] as String?,
      userId: map['user_id'] as String?,
      coupleId: map['couple_id'] as String?,
      nickname: map['nickname'] as String?,
      coupleStartDate: coupleStartDate,
      coupleType: map['couple_type'] as String? ?? 'distance',
      distanceType: map['distance_type'] as String? ?? 'same_city',
      myCity: map['my_city'] as String?,
      myStation: map['my_station'] as String?,
      partnerCity: map['partner_city'] as String?,
      partnerStation: map['partner_station'] as String?,
      workPattern: map['work_pattern'] as String? ?? 'office',
      shiftTimes: shifts,
      notifyMinutesBefore: map['notify_minutes_before'] as int? ?? 30,
      hasCar: map['has_car'] as bool? ?? false,
      onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
    );
  }

  /// Supabase 저장용 직렬화 — shift_times 는 List<Map> 으로 유지 (하위 호환)
  Map<String, dynamic> toMap() => {
    'couple_type': coupleType,
    'distance_type': distanceType,
    'my_city': myCity,
    'my_station': myStation,
    'partner_city': partnerCity,
    'partner_station': partnerStation,
    'work_pattern': workPattern,
    'shift_times': shiftTimes.map((s) => s.toMap()).toList(),
    'notify_minutes_before': notifyMinutesBefore,
    'has_car': hasCar,
    'onboarding_completed': onboardingCompleted,
  };

  CoupleProfile copyWith({
    String? id,
    String? userId,
    String? coupleId,
    String? nickname,
    DateTime? coupleStartDate,
    String? coupleType,
    String? distanceType,
    String? myCity,
    String? myStation,
    String? partnerCity,
    String? partnerStation,
    String? workPattern,
    List<ShiftTime>? shiftTimes,
    int? notifyMinutesBefore,
    bool? hasCar,
    bool? onboardingCompleted,
  }) => CoupleProfile(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    coupleId: coupleId ?? this.coupleId,
    nickname: nickname ?? this.nickname,
    coupleStartDate: coupleStartDate ?? this.coupleStartDate,
    coupleType: coupleType ?? this.coupleType,
    distanceType: distanceType ?? this.distanceType,
    myCity: myCity ?? this.myCity,
    myStation: myStation ?? this.myStation,
    partnerCity: partnerCity ?? this.partnerCity,
    partnerStation: partnerStation ?? this.partnerStation,
    workPattern: workPattern ?? this.workPattern,
    shiftTimes: shiftTimes ?? this.shiftTimes,
    notifyMinutesBefore: notifyMinutesBefore ?? this.notifyMinutesBefore,
    hasCar: hasCar ?? this.hasCar,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
}

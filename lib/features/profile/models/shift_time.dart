import 'package:flutter/material.dart';

/// 근무 시간 타입 모델
/// Supabase JSONB 직렬화 시 snake_case key 유지 (호환성)
class ShiftTime {
  final String shiftType; // 'D' | 'E' | 'N' | 'day' | 'night' | 'office'
  final String label;     // 하위 호환용 저장 필드, 현재는 shiftType과 동일하게 관리
  final String? colorHex; // 코드별 사용자 지정 색상
  final bool isAllDay;    // 종일 근무 여부
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool isNextDay;   // 종료가 익일인지 (밤번)

  const ShiftTime({
    required this.shiftType,
    this.label = '',
    this.colorHex,
    this.isAllDay = false,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.isNextDay = false,
  });

  TimeOfDay get startTime => TimeOfDay(hour: startHour, minute: startMinute);
  TimeOfDay get endTime => TimeOfDay(hour: endHour, minute: endMinute);

  /// 근무 종료 DateTime 계산 (알림 스케줄링용)
  DateTime endDateTime(DateTime workDate) {
    final end = DateTime(
      workDate.year,
      workDate.month,
      workDate.day,
      endHour,
      endMinute,
    );
    return isNextDay ? end.add(const Duration(days: 1)) : end;
  }

  /// Supabase JSONB 호환 직렬화 (shift_defaults.dart 와 동일한 key 사용)
  Map<String, dynamic> toMap() => {
    'shift_type': shiftType,
    'label': label.isNotEmpty ? label : shiftType,
    'color_hex': colorHex,
    'is_all_day': isAllDay,
    'start_h': startHour,
    'start_m': startMinute,
    'end_h': endHour,
    'end_m': endMinute,
    'is_next_day': isNextDay,
  };

  /// Map (shift_defaults / Supabase) 에서 생성
  factory ShiftTime.fromMap(Map<String, dynamic> map) {
    final shiftType = map['shift_type'] as String;
    return ShiftTime(
      shiftType: shiftType,
      label: (map['label'] as String?)?.trim().isNotEmpty == true
          ? map['label'] as String
          : shiftType,
      colorHex: map['color_hex'] as String?,
        isAllDay: map['is_all_day'] as bool? ?? false,
      startHour: map['start_h'] as int,
      startMinute: map['start_m'] as int,
      endHour: map['end_h'] as int,
      endMinute: map['end_m'] as int,
      isNextDay: map['is_next_day'] as bool? ?? false,
    );
  }

  ShiftTime copyWith({
    String? shiftType,
    String? label,
    String? colorHex,
    bool? isAllDay,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    bool? isNextDay,
  }) => ShiftTime(
    shiftType: shiftType ?? this.shiftType,
    label: label ?? this.label,
    colorHex: colorHex ?? this.colorHex,
    isAllDay: isAllDay ?? this.isAllDay,
    startHour: startHour ?? this.startHour,
    startMinute: startMinute ?? this.startMinute,
    endHour: endHour ?? this.endHour,
    endMinute: endMinute ?? this.endMinute,
    isNextDay: isNextDay ?? this.isNextDay,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftTime &&
          shiftType == other.shiftType &&
          label == other.label &&
          colorHex == other.colorHex &&
          isAllDay == other.isAllDay &&
          startHour == other.startHour &&
          startMinute == other.startMinute &&
          endHour == other.endHour &&
          endMinute == other.endMinute &&
          isNextDay == other.isNextDay;

  @override
  int get hashCode => Object.hash(
      shiftType,
      label,
      colorHex,
      isAllDay,
      startHour,
      startMinute,
      endHour,
      endMinute,
      isNextDay,
    );
}

import 'package:flutter/material.dart';

class Schedule {
  final String id;
  final String userId;
  final String? coupleId;
  final DateTime date;

  // 공유 캘린더 확장 필드
  final String? title;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? category; // '근무', '약속', '여행', '데이트', '기타'
  final String? location;
  final String? note;
  final int? reminderMinutes; // 알림 시간(분)
  final Map<String, dynamic>? repeatPattern; // JSON 형식
  final bool isAnniversary;

  // OCR 관련 필드 (원본 보관용)
  final String? workType;
  final String? colorHex;
  final bool isDate;
  final String? emoji;

  const Schedule({
    required this.id,
    required this.userId,
    required this.coupleId,
    required this.date,
    this.title,
    this.startTime,
    this.endTime,
    this.category,
    this.location,
    this.note,
    this.reminderMinutes,
    this.repeatPattern,
    this.isAnniversary = false,
    this.workType,
    this.colorHex,
    this.isDate = false,
    this.emoji,
  });

  factory Schedule.fromMap(Map<String, dynamic> map) => Schedule(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        coupleId: map['couple_id'] as String?,
        date: DateTime.parse(map['date'] as String),
        title: map['title'] as String?,
        startTime: map['start_time'] != null
            ? _parseTime(map['start_time'] as String)
            : null,
        endTime: map['end_time'] != null
            ? _parseTime(map['end_time'] as String)
            : null,
        category: map['category'] as String?,
        location: map['location'] as String?,
        note: map['note'] as String?,
        reminderMinutes: map['reminder_minutes'] as int?,
        repeatPattern: map['repeat_pattern'] != null
            ? map['repeat_pattern'] as Map<String, dynamic>
            : null,
        isAnniversary: map['is_anniversary'] as bool? ?? false,
        workType: map['work_type'] as String?,
        colorHex: map['color_hex'] as String?,
        isDate: map['is_date'] as bool? ?? false,
        emoji: map['emoji'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'couple_id': coupleId,
        'date': date.toIso8601String().split('T')[0],
        'title': title,
        'start_time': _formatTime(startTime),
        'end_time': _formatTime(endTime),
        'category': category,
        'location': location,
        'note': note,
        'reminder_minutes': reminderMinutes,
        'repeat_pattern': repeatPattern,
        'is_anniversary': isAnniversary,
        'work_type': workType,
        'color_hex': colorHex,
        'is_date': isDate,
        'emoji': emoji,
      };

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Schedule copyWith({
    String? id,
    String? userId,
    String? coupleId,
    DateTime? date,
    String? title,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? category,
    String? location,
    String? note,
    int? reminderMinutes,
    Map<String, dynamic>? repeatPattern,
    bool? isAnniversary,
    String? workType,
    String? colorHex,
    bool? isDate,
    String? emoji,
  }) {
    return Schedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      coupleId: coupleId ?? this.coupleId,
      date: date ?? this.date,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      location: location ?? this.location,
      note: note ?? this.note,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      repeatPattern: repeatPattern ?? this.repeatPattern,
      isAnniversary: isAnniversary ?? this.isAnniversary,
      workType: workType ?? this.workType,
      colorHex: colorHex ?? this.colorHex,
      isDate: isDate ?? this.isDate,
      emoji: emoji ?? this.emoji,
    );
  }
}

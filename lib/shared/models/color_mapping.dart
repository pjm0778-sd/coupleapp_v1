import 'package:flutter/material.dart';

class ColorMapping {
  final String id;
  final String? userId;
  final String colorHex;

  // 일정 자동등록 확장 필드
  final String title; // 필수
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  // 기존 호환용 (workType를 title로 사용)
  String get workType => title;

  const ColorMapping({
    required this.id,
    this.userId,
    required this.colorHex,
    required this.title,
    this.startTime,
    this.endTime,
  });

  factory ColorMapping.fromMap(Map<String, dynamic> map) => ColorMapping(
    id: map['id'] as String,
    userId: map['user_id'] as String?,
    colorHex: map['color_hex'] as String,
    title: map['work_type'] as String? ?? '일정',
    startTime: map['start_time'] != null
        ? _parseTime(map['start_time'] as String)
        : null,
    endTime: map['end_time'] != null
        ? _parseTime(map['end_time'] as String)
        : null,
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'color_hex': colorHex,
    'work_type': title,
  };

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

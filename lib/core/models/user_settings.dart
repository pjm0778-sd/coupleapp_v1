import 'shift_type.dart';

class UserSettings {
  final String id;
  final String userId;
  final ShiftType shiftType;
  final String defaultShift;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    required this.id,
    required this.userId,
    required this.shiftType,
    required this.defaultShift,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      shiftType: ShiftType.fromString(json['shift_type'] as String),
      defaultShift: json['default_shift'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'shift_type': shiftType.value,
      'default_shift': defaultShift,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserSettings copyWith({
    String? id,
    String? userId,
    ShiftType? shiftType,
    String? defaultShift,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      shiftType: shiftType ?? this.shiftType,
      defaultShift: defaultShift ?? this.defaultShift,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

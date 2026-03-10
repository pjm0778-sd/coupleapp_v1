class Schedule {
  final String id;
  final String userId;
  final String? coupleId;
  final DateTime date;
  final String? workType;
  final String? colorHex;
  final String? note;
  final bool isDate;
  final String? emoji;

  const Schedule({
    required this.id,
    required this.userId,
    required this.coupleId,
    required this.date,
    this.workType,
    this.colorHex,
    this.note,
    this.isDate = false,
    this.emoji,
  });

  factory Schedule.fromMap(Map<String, dynamic> map) => Schedule(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        coupleId: map['couple_id'] as String?,
        date: DateTime.parse(map['date'] as String),
        workType: map['work_type'] as String?,
        colorHex: map['color_hex'] as String?,
        note: map['note'] as String?,
        isDate: map['is_date'] as bool? ?? false,
        emoji: map['emoji'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'couple_id': coupleId,
        'date': date.toIso8601String().split('T')[0],
        'work_type': workType,
        'color_hex': colorHex,
        'note': note,
        'is_date': isDate,
        'emoji': emoji,
      };
}

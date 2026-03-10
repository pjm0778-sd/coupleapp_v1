class ScheduleComment {
  final String id;
  final String scheduleId;
  final String userId;
  final String content;
  final DateTime createdAt;

  ScheduleComment({
    required this.id,
    required this.scheduleId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory ScheduleComment.fromMap(Map<String, dynamic> map) => ScheduleComment(
        id: map['id'] as String,
        scheduleId: map['schedule_id'] as String,
        userId: map['user_id'] as String,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'schedule_id': scheduleId,
        'user_id': userId,
        'content': content,
      };
}

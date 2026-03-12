import 'package:flutter/material.dart';

enum NotificationType {
  scheduleAdded,
  scheduleDeleted,
  scheduleUpdated,
  commentAdded,
  bothOff,
  dateBefore,
  dateToday,
}

extension NotificationTypeExtension on NotificationType {
  String toStringValue() {
    switch (this) {
      case NotificationType.scheduleAdded:
        return 'schedule_added';
      case NotificationType.scheduleDeleted:
        return 'schedule_deleted';
      case NotificationType.scheduleUpdated:
        return 'schedule_updated';
      case NotificationType.commentAdded:
        return 'comment_added';
      case NotificationType.bothOff:
        return 'both_off';
      case NotificationType.dateBefore:
        return 'date_before';
      case NotificationType.dateToday:
        return 'date_today';
    }
  }

  String get displayName {
    switch (this) {
      case NotificationType.scheduleAdded:
        return '일정 추가';
      case NotificationType.scheduleDeleted:
        return '일정 삭제';
      case NotificationType.scheduleUpdated:
        return '일정 수정';
      case NotificationType.commentAdded:
        return '댓글 추가';
      case NotificationType.bothOff:
        return '둘 다 휴무';
      case NotificationType.dateBefore:
        return '데이트 하루 전';
      case NotificationType.dateToday:
        return '데이트 당일';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.scheduleAdded:
        return Icons.add_circle_outline;
      case NotificationType.scheduleDeleted:
        return Icons.delete_outline;
      case NotificationType.scheduleUpdated:
        return Icons.mode_edit_outline;
      case NotificationType.commentAdded:
        return Icons.comment_outlined;
      case NotificationType.bothOff:
        return Icons.favorite_border;
      case NotificationType.dateBefore:
        return Icons.calendar_today_outlined;
      case NotificationType.dateToday:
        return Icons.favorite;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.scheduleAdded:
        return Colors.green;
      case NotificationType.scheduleDeleted:
        return Colors.red;
      case NotificationType.scheduleUpdated:
        return Colors.orange;
      case NotificationType.commentAdded:
        return Colors.blue;
      case NotificationType.bothOff:
        return Colors.pink;
      case NotificationType.dateBefore:
        return Colors.blue;
      case NotificationType.dateToday:
        return Colors.pink;
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'schedule_added':
        return NotificationType.scheduleAdded;
      case 'schedule_deleted':
        return NotificationType.scheduleDeleted;
      case 'schedule_updated':
        return NotificationType.scheduleUpdated;
      case 'comment_added':
        return NotificationType.commentAdded;
      case 'both_off':
        return NotificationType.bothOff;
      case 'date_before':
        return NotificationType.dateBefore;
      case 'date_today':
        return NotificationType.dateToday;
      default:
        return NotificationType.scheduleAdded;
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  bool isRead;
  final NotificationType type;

  AppNotification({
    required this.id,
    required this.title,
    this.body,
    required this.createdAt,
    this.isRead = false,
    required this.type,
  });

  factory AppNotification.fromRealtime({
    required String id,
    required String title,
    String? body,
    required NotificationType type,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      isRead: false,
      type: type,
    );
  }

  AppNotification markAsRead() {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: true,
      type: type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'type': type.toStringValue(),
    };
  }
}

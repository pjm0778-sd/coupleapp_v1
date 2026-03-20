import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../models/notification.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = NotificationManager();
    final history = manager.history;
    final scheduleAlerts = history
        .where(
          (n) =>
              n.type == NotificationType.scheduleAdded ||
              n.type == NotificationType.scheduleDeleted ||
              n.type == NotificationType.scheduleUpdated ||
              n.type == NotificationType.commentAdded,
        )
        .toList();

    final generalAlerts = history
        .where((n) => !scheduleAlerts.contains(n))
        .toList();

    final unreadCount = history.where((n) => !n.isRead).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('알림${unreadCount > 0 ? ' ($unreadCount)' : ''}'),
          actions: [
            if (unreadCount > 0)
              TextButton(
                onPressed: () {
                  manager.markAllAsRead();
                },
                child: const Text('모두 읽음', style: TextStyle(fontSize: 13)),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '일반 알림'),
              Tab(text: '이벤트 알림'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildNotificationList(generalAlerts),
            _buildNotificationList(scheduleAlerts),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    return notifications.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  color: AppTheme.textSecondary,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  '알림이 없어요',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final notification = notifications[index];
              return _NotificationCard(notification: notification);
            },
          );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isRead ? AppTheme.surface : AppTheme.accentLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [AppTheme.subtleShadow],
        border: notification.isRead
            ? null
            : Border(left: BorderSide(color: AppTheme.accent, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: notification.type.color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              notification.type.icon,
              color: notification.type.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (notification.body != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.body!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatTime(notification.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays == 1) {
      return '어제';
    } else {
      return '${dateTime.month}월 ${dateTime.day}일';
    }
  }
}

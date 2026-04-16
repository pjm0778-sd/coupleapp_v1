import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../models/notification_settings.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final manager = NotificationManager();
    final settings = manager.settings;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('알림 설정'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Container(
        decoration: AppTheme.pageGradient,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // 일정 알림
            _buildSectionHeader('내 애인 일정 알림'),
            _buildSwitchTile(
              title: '내 애인 일정 추가 알림',
              subtitle: '내 애인이 일정을 추가하면 알림',
              value: settings.scheduleAdded,
              onChanged: (value) {
                manager.updateSettings(settings.copyWith(scheduleAdded: value));
                setState(() {});
              },
            ),
            _buildSwitchTile(
              title: '내 애인 일정 삭제 알림',
              subtitle: '내 애인이 일정을 삭제하면 알림',
              value: settings.scheduleDeleted,
              onChanged: (value) {
                manager.updateSettings(
                  settings.copyWith(scheduleDeleted: value),
                );
                setState(() {});
              },
            ),
            _buildSwitchTile(
              title: '내 애인 일정 수정 알림',
              subtitle: '내 애인이 일정을 수정하면 알림',
              value: settings.scheduleUpdated,
              onChanged: (value) {
                manager.updateSettings(
                  settings.copyWith(scheduleUpdated: value),
                );
                setState(() {});
              },
            ),
            _buildSwitchTile(
              title: '댓글 알림',
              subtitle: '내 애인이 일정에 댓글을 남기면 알림',
              value: settings.commentAdded,
              onChanged: (value) {
                manager.updateSettings(settings.copyWith(commentAdded: value));
                setState(() {});
              },
            ),

            const SizedBox(height: 8),

            // 출퇴근 알림
            _buildSectionHeader('파트너 출퇴근 알림'),
            _buildSwitchTile(
              title: '파트너 출퇴근 알림',
              subtitle: '파트너의 출근·퇴근 시간에 맞춰 매일 알림',
              value: settings.partnerCommuteAlerts,
              onChanged: (value) {
                manager.updateSettings(
                  settings.copyWith(partnerCommuteAlerts: value),
                );
                if (value) {
                  NotificationService().scheduleCommuteAlertsForPartner();
                } else {
                  manager.cancelPartnerCommuteAlerts();
                }
                setState(() {});
              },
            ),

            const SizedBox(height: 8),

            // 스케줄링 알림
            _buildSectionHeader('스케줄링 알림'),
            _buildSwitchTile(
              title: '둘 다 휴무 알림',
              subtitle: '둘 다 쉬는 날에 앱 화면 진입 시 알림',
              value: settings.bothOff,
              onChanged: (value) {
                manager.updateSettings(settings.copyWith(bothOff: value));
                setState(() {});
              },
            ),
            _buildSwitchTile(
              title: '데이트 하루 전 알림',
              subtitle: '데이트 하루 전에 앱 화면 진입 시 알림',
              value: settings.dateBefore,
              onChanged: (value) {
                manager.updateSettings(settings.copyWith(dateBefore: value));
                setState(() {});
              },
            ),
            _buildSwitchTile(
              title: '데이트 당일 알림',
              subtitle: '데이트 당일에 앱 화면 진입 시 알림',
              value: settings.dateToday,
              onChanged: (value) {
                manager.updateSettings(settings.copyWith(dateToday: value));
                setState(() {});
              },
            ),

            const SizedBox(height: 20),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [AppTheme.subtleShadow],
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textSecondary),
              )
            : null,
        value: value,
        activeTrackColor: AppTheme.primaryLight,
        activeColor: AppTheme.primary,
        inactiveTrackColor: AppTheme.border,
        inactiveThumbColor: AppTheme.textTertiary,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _toggleAll(false),
              icon: const Icon(Icons.notifications_off_outlined, size: 18),
              label: const Text('모두 끄기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.border),
                backgroundColor: AppTheme.surface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _toggleAll(true),
              icon: const Icon(Icons.notifications_active, size: 18),
              label: const Text('모두 켜기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAll(bool value) {
    final manager = NotificationManager();
    manager.updateSettings(
      NotificationSettings(
        scheduleAdded: value,
        scheduleDeleted: value,
        scheduleUpdated: value,
        commentAdded: value,
        bothOff: value,
        dateBefore: value,
        dateToday: value,
        partnerCommuteAlerts: value,
      ),
    );
    setState(() {});
  }
}

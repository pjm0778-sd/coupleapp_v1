import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../models/notification_settings.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = NotificationManager();
    final settings = manager.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        children: [
          _buildSectionHeader('파트너 일정 알림'),
          _buildSwitchTile(
            title: '파트너 일정 추가 알림',
            subtitle: '파트너가 일정을 추가하면 알림',
            value: settings.scheduleAdded,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(scheduleAdded: value),
            ),
          ),
          _buildSwitchTile(
            title: '파트너 일정 삭제 알림',
            subtitle: '파트너가 일정을 삭제하면 알림',
            value: settings.scheduleDeleted,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(scheduleDeleted: value),
            ),
          ),
          _buildSwitchTile(
            title: '파트너 일정 수정 알림',
            subtitle: '파트너가 일정을 수정하면 알림',
            value: settings.scheduleUpdated,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(scheduleUpdated: value),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('스케줄링 알림'),
          _buildSwitchTile(
            title: '둘 다 휴무 알림',
            subtitle: '둘 다 쉬는 날 오전 9시에 알림',
            value: settings.bothOff,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(bothOff: value),
            ),
          ),
          _buildSwitchTile(
            title: '데이트 하루 전 알림',
            subtitle: '데이트 하루 전 오전 9시에 알림',
            value: settings.dateBefore,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(dateBefore: value),
            ),
          ),
          _buildSwitchTile(
            title: '데이트 당일 알림',
            subtitle: '데이트 당일 오전 9시에 알림',
            value: settings.dateToday,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(dateToday: value),
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
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
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      activeColor: AppTheme.primary,
      onChanged: onChanged,
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
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.border),
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
    final settings = manager.settings;
    manager.updateSettings(
      NotificationSettings(
        scheduleAdded: value,
        scheduleDeleted: value,
        scheduleUpdated: value,
        bothOff: value,
        dateBefore: value,
        dateToday: value,
      ),
    );
  }
}

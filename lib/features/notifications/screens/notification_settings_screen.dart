import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../models/notification_settings.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _permissionGranted = NotificationManager().webPermissionGranted;
  }

  @override
  Widget build(BuildContext context) {
    final manager = NotificationManager();
    final settings = manager.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        children: [
          _buildSectionHeader('알림 권한'),
          if (kIsWeb) _buildPermissionCard(manager, _permissionGranted),
          const SizedBox(height: 20),
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

  Widget _buildPermissionCard(NotificationManager manager, bool permissionGranted) {
    // 플랫폼별로 권한 상태 확인
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: permissionGranted ? AppTheme.surface : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: permissionGranted ? AppTheme.border : Colors.amber.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  permissionGranted ? Icons.notifications_active : Icons.notifications_none,
                  color: permissionGranted ? AppTheme.primary : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        permissionGranted ? '알림 권한 허용됨' : '알림 권한 필요',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: permissionGranted ? AppTheme.textPrimary : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        permissionGranted
                            ? '브라우저 알림이 활성화되어 있습니다'
                            : '알림을 받으려면 권한을 허용해주세요',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!permissionGranted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _requestPermission(manager),
                  icon: const Icon(Icons.notifications, size: 18),
                  label: const Text('알림 권한 허용'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermission(NotificationManager manager) async {
    final result = await manager.requestWebNotificationPermission();

    if (!mounted) return;

    if (result == 'granted') {
      setState(() {
        _permissionGranted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 권한이 허용되었습니다')),
      );
    } else if (result == 'denied') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 권한이 거부되었습니다')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 권한 요청 중 오류가 발생했습니다')),
      );
    }
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
      activeTrackColor: AppTheme.primary,
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

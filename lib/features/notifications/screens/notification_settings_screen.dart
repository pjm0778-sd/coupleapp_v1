import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/notification_manager.dart';
import '../models/notification_settings.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _permissionGranted = false;
  bool _checkingPermission = false;

  @override
  void initState() {
    super.initState();
    _permissionGranted = NotificationManager().webPermissionGranted;
  }

  Future<void> _requestPermission() async {
    setState(() => _checkingPermission = true);
    try {
      if (kIsWeb) {
        final result = await NotificationManager()
            .requestWebNotificationPermission();
        if (mounted) {
          setState(() => _permissionGranted = result == 'granted');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == 'granted' ? '알림 권한을 허용했습니다.' : '알림 권한을 거부했습니다.',
              ),
            ),
          );
        }
      } else {
        final granted = await NotificationManager().requestPermission();
        if (mounted) {
          setState(() => _permissionGranted = granted);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                granted ? '알림 권한을 허용했습니다.' : '알림 권한을 거부했습니다. 설정 앱에서 직접 허용해주세요.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('알림 권한 요청 중 오류가 발생했습니다')));
      }
    } finally {
      if (mounted) setState(() => _checkingPermission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = NotificationManager();
    final settings = manager.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        children: [
          // 알림 권한 카드
          _buildSectionHeader('알림 권한'),
          _buildPermissionCard(),
          const SizedBox(height: 8),

          // 일정 알림
          _buildSectionHeader('내 애인 일정 알림'),
          _buildSwitchTile(
            title: '내 애인 일정 추가 알림',
            subtitle: '내 애인이 일정을 추가하면 알림',
            value: settings.scheduleAdded,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(scheduleAdded: value)),
          ),
          _buildSwitchTile(
            title: '내 애인 일정 삭제 알림',
            subtitle: '내 애인이 일정을 삭제하면 알림',
            value: settings.scheduleDeleted,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(scheduleDeleted: value),
            ),
          ),
          _buildSwitchTile(
            title: '내 애인 일정 수정 알림',
            subtitle: '내 애인이 일정을 수정하면 알림',
            value: settings.scheduleUpdated,
            onChanged: (value) => manager.updateSettings(
              settings.copyWith(scheduleUpdated: value),
            ),
          ),

          const SizedBox(height: 8),

          // 출퇴근 알림
          _buildSectionHeader('파트너 출퇴근 알림'),
          _buildSwitchTile(
            title: '파트너 출퇴근 알림',
            subtitle: '파트너의 출근·퇴근 시간에 맞춰 매일 알림',
            value: settings.partnerCommuteAlerts,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(partnerCommuteAlerts: value)),
          ),

          const SizedBox(height: 8),

          // 스케줄링 알림
          _buildSectionHeader('스케줄링 알림'),
          _buildSwitchTile(
            title: '둘 다 휴무 알림',
            subtitle: '둘 다 쉬는 날에 앱 화면 진입 시 알림',
            value: settings.bothOff,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(bothOff: value)),
          ),
          _buildSwitchTile(
            title: '데이트 하루 전 알림',
            subtitle: '데이트 하루 전에 앱 화면 진입 시 알림',
            value: settings.dateBefore,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(dateBefore: value)),
          ),
          _buildSwitchTile(
            title: '데이트 당일 알림',
            subtitle: '데이트 당일에 앱 화면 진입 시 알림',
            value: settings.dateToday,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(dateToday: value)),
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

  Widget _buildPermissionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _permissionGranted ? AppTheme.surface : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _permissionGranted ? AppTheme.border : Colors.amber.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _permissionGranted
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  color: _permissionGranted ? AppTheme.primary : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _permissionGranted ? '알림 권한 허용됨' : '알림 권한 필요',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _permissionGranted
                              ? AppTheme.textPrimary
                              : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _permissionGranted
                            ? '시스템 알림이 활성화되어 있습니다'
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
            if (!_permissionGranted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _checkingPermission ? null : _requestPermission,
                  icon: _checkingPermission
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.notifications, size: 18),
                  label: Text(_checkingPermission ? '요청 중...' : '알림 권한 허용'),
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

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
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
                side: const BorderSide(color: AppTheme.border),
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

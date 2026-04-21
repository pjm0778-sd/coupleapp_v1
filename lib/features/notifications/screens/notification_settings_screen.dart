import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _loadingPlatformStatus = true;
  bool? _androidExactAlarmAvailable;

  @override
  void initState() {
    super.initState();
    _loadPlatformStatus();
  }

  Future<void> _loadPlatformStatus() async {
    setState(() => _loadingPlatformStatus = true);
    final manager = NotificationManager();
    final exact = await manager.canScheduleExactAlarms();
    if (!mounted) return;
    setState(() {
      _androidExactAlarmAvailable = exact;
      _loadingPlatformStatus = false;
    });
  }

  Future<void> _requestNotificationPermission() async {
    final manager = NotificationManager();
    final granted = await manager.requestPermission();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted ? '알림 권한이 허용되었어요.' : '알림 권한이 거부되었어요.'),
      ),
    );
    await _loadPlatformStatus();
  }

  Future<void> _requestExactAlarmIfNeeded() async {
    final manager = NotificationManager();
    final result = await manager.requestExactAlarmsPermissionIfNeeded();
    if (!mounted) return;
    final message = switch (result) {
      true => '정확 알람 사용 가능 상태예요.',
      false => '정확 알람이 꺼져 있어 일부 알림이 지연될 수 있어요.',
      null => '이 기기에서는 정확 알람 상태를 확인할 수 없어요.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    await _loadPlatformStatus();
  }

  Future<void> _openSystemSettings() async {
    final uri = Uri.parse('app-settings:');
    final opened = await launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시스템 설정을 열지 못했어요.')), 
      );
    }
  }

  Future<void> _showDiagnosticLogs() async {
    final manager = NotificationManager();
    final logs = await manager.getRecentDiagnosticLogs(limit: 60);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    children: [
                      const Text(
                        '알림 진단 로그',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: logs.isEmpty
                      ? const Center(
                          child: Text(
                            '저장된 로그가 없어요.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Text(
                              logs[i],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearDiagnosticLogs() async {
    final manager = NotificationManager();
    await manager.clearDiagnosticLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('진단 로그를 비웠어요.')),
    );
  }

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

            const SizedBox(height: 8),

            _buildSectionHeader('운영/진단'),
            _buildSwitchTile(
              title: '알림 진단 로그 저장',
              subtitle: '예약/발송 이벤트를 기기 내에 기록',
              value: settings.diagnosticLogs,
              onChanged: (value) {
                manager.updateSettings(settings.copyWith(diagnosticLogs: value));
                setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: settings.diagnosticLogs ? _showDiagnosticLogs : null,
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: const Text('진단 로그 보기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: settings.diagnosticLogs ? _clearDiagnosticLogs : null,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('진단 로그 비우기'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // 플랫폼 상태 안내
            _buildSectionHeader('플랫폼 상태 안내'),
            _buildPlatformStatusCard(),

            const SizedBox(height: 20),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformStatusCard() {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [AppTheme.subtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '알림 전달 안정성',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (_loadingPlatformStatus)
            const Text(
              '기기 상태를 확인 중이에요...',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else if (isAndroid)
            Text(
              'Android 정확 알람: ${_androidExactAlarmAvailable == true ? '사용 가능' : _androidExactAlarmAvailable == false ? '비활성(지연 가능)' : '확인 불가'}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else if (isIos)
            const Text(
              'iOS는 집중 모드/알림 요약 설정에 따라 알림 표시 시점이 달라질 수 있어요.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else
            const Text(
              '현재 플랫폼 상태 안내를 제공하지 않아요.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _requestNotificationPermission,
                icon: const Icon(Icons.notifications_active_outlined, size: 16),
                label: const Text('권한 요청'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.border),
                ),
              ),
              if (isAndroid)
                OutlinedButton.icon(
                  onPressed: _requestExactAlarmIfNeeded,
                  icon: const Icon(Icons.alarm_on_outlined, size: 16),
                  label: const Text('정확 알람 확인'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                  ),
                ),
              if (isAndroid)
                OutlinedButton.icon(
                  onPressed: _openSystemSettings,
                  icon: const Icon(Icons.battery_alert_outlined, size: 16),
                  label: const Text('배터리 최적화 확인'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.border),
                  ),
                ),
            ],
          ),
          if (isAndroid) ...[
            const SizedBox(height: 10),
            const Text(
              '일부 기기는 배터리 최적화가 켜져 있으면 예약 알림이 지연될 수 있어요. 시스템 설정에서 앱 절전 예외를 확인해 주세요.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
            ),
          ],
        ],
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
        diagnosticLogs: value,
      ),
    );
    setState(() {});
  }
}

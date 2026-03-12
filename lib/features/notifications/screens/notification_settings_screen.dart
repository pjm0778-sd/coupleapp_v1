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
        final result =
            await NotificationManager().requestWebNotificationPermission();
        if (mounted) {
          setState(() => _permissionGranted = result == 'granted');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result == 'granted'
                  ? '?뚮┝ 沅뚰븳???덉슜?섏뿀?듬땲??
                  : '?뚮┝ 沅뚰븳??嫄곕??섏뿀?듬땲??),
            ),
          );
        }
      } else {
        final granted = await NotificationManager().requestPermission();
        if (mounted) {
          setState(() => _permissionGranted = granted);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(granted
                  ? '?뚮┝ 沅뚰븳???덉슜?섏뿀?듬땲????
                  : '?뚮┝ 沅뚰븳??嫄곕??섏뿀?듬땲?? ?ㅼ젙 ?깆뿉??吏곸젒 ?덉슜?댁＜?몄슂.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('?뚮┝ 沅뚰븳 ?붿껌 以??ㅻ쪟媛 諛쒖깮?덉뒿?덈떎')),
        );
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
      appBar: AppBar(title: const Text('?뚮┝ ?ㅼ젙')),
      body: ListView(
        children: [
          // ?? 沅뚰븳 移대뱶 (紐⑤컮??Web 怨듯넻) ??
          _buildSectionHeader('?뚮┝ 沅뚰븳'),
          _buildPermissionCard(),
          const SizedBox(height: 8),

          // ?? ?뚰듃???쇱젙 ?뚮┝ ??
          _buildSectionHeader('?뚰듃???쇱젙 ?뚮┝'),
          _buildSwitchTile(
            title: '?뚰듃???쇱젙 異붽? ?뚮┝',
            subtitle: '?뚰듃?덇? ?쇱젙??異붽??섎㈃ ?뚮┝',
            value: settings.scheduleAdded,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(scheduleAdded: value)),
          ),
          _buildSwitchTile(
            title: '?뚰듃???쇱젙 ??젣 ?뚮┝',
            subtitle: '?뚰듃?덇? ?쇱젙????젣?섎㈃ ?뚮┝',
            value: settings.scheduleDeleted,
            onChanged: (value) => manager
                .updateSettings(settings.copyWith(scheduleDeleted: value)),
          ),
          _buildSwitchTile(
            title: '?뚰듃???쇱젙 ?섏젙 ?뚮┝',
            subtitle: '?뚰듃?덇? ?쇱젙???섏젙?섎㈃ ?뚮┝',
            value: settings.scheduleUpdated,
            onChanged: (value) => manager
                .updateSettings(settings.copyWith(scheduleUpdated: value)),
          ),

          const SizedBox(height: 8),

          // ?? ?ㅼ?以꾨쭅 ?뚮┝ ??
          _buildSectionHeader('?ㅼ?以꾨쭅 ?뚮┝'),
          _buildSwitchTile(
            title: '?????대Т ?뚮┝',
            subtitle: '?????щ뒗 ?????붾㈃ 吏꾩엯 ???뚮┝',
            value: settings.bothOff,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(bothOff: value)),
          ),
          _buildSwitchTile(
            title: '?곗씠???섎（ ???뚮┝',
            subtitle: '?곗씠???섎（ ?????붾㈃ 吏꾩엯 ???뚮┝',
            value: settings.dateBefore,
            onChanged: (value) =>
                manager.updateSettings(settings.copyWith(dateBefore: value)),
          ),
          _buildSwitchTile(
            title: '?곗씠???뱀씪 ?뚮┝',
            subtitle: '?곗씠???뱀씪 ???붾㈃ 吏꾩엯 ???뚮┝',
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
          color: _permissionGranted
              ? AppTheme.surface
              : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _permissionGranted
                ? AppTheme.border
                : Colors.amber.shade300,
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
                        _permissionGranted ? '?뚮┝ 沅뚰븳 ?덉슜?? : '?뚮┝ 沅뚰븳 ?꾩슂',
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
                            ? '?쒖뒪???뚮┝???쒖꽦?붾릺???덉뒿?덈떎'
                            : '?뚮┝??諛쏆쑝?ㅻ㈃ 沅뚰븳???덉슜?댁＜?몄슂',
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
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.notifications, size: 18),
                  label: Text(_checkingPermission ? '?붿껌 以?..' : '?뚮┝ 沅뚰븳 ?덉슜'),
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
              label: const Text('紐⑤몢 ?꾧린'),
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
              label: const Text('紐⑤몢 耳쒓린'),
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
    manager.updateSettings(NotificationSettings(
      scheduleAdded: value,
      scheduleDeleted: value,
      scheduleUpdated: value,
      bothOff: value,
      dateBefore: value,
      dateToday: value,
    ));
    setState(() {});
  }
}

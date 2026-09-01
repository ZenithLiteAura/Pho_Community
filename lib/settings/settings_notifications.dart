import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/notifications/local_notifier.dart';
import 'package:img_syncer/settings/settings_sync_notify.dart';

/// 二级页：通知 —— 通知权限状态 + 同步通知入口。
class SettingsNotificationsPage extends StatefulWidget {
  const SettingsNotificationsPage({Key? key}) : super(key: key);

  @override
  State<SettingsNotificationsPage> createState() =>
      _SettingsNotificationsPageState();
}

class _SettingsNotificationsPageState extends State<SettingsNotificationsPage> {
  bool _notificationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 查询通知权限状态
    try {
      final granted = await LocalNotifier.checkAuthorizationStatus();
      if (mounted) {
        setState(() {
          _notificationPermissionGranted = granted;
        });
      }
    } catch (_) {
      // 非 iOS 平台或 platform channel 未注册时忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsAndPermissions)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _sectionHeader(context, l10n.notificationsAndPermissions),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _notificationPermissionGranted
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 26,
                  ),
                  title: Text(l10n.notificationPermissionStatus),
                  subtitle: Text(
                    _notificationPermissionGranted
                        ? l10n.notificationPermissionGranted
                        : l10n.notificationPermissionNotGranted,
                    style: TextStyle(
                      color: _notificationPermissionGranted
                          ? AppColors.accentSuccess
                          : AppColors.error,
                    ),
                  ),
                  onTap: () async {
                    final granted =
                        await LocalNotifier.requestNotificationPermission();
                    if (mounted) {
                      setState(() {
                        _notificationPermissionGranted = granted;
                      });
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined, size: 26),
                  title: Text(l10n.syncNotify),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsSyncNotifyPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

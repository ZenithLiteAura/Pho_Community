import 'package:flutter/material.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/settings/settings_account.dart';
import 'package:img_syncer/settings/settings_storage.dart';
import 'package:img_syncer/settings/settings_notifications.dart';
import 'package:img_syncer/settings/settings_appearance.dart';
import 'package:img_syncer/settings/settings_about.dart';

/// 一级设置页：设置分类入口。
/// 主题风格等具体设置统一放在对应二级页中，避免重复入口。
class SettingsHome extends StatelessWidget {
  const SettingsHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _buildHeaderCard(context),
          _sectionHeader(context, l10n.settings),
          RepaintBoundary(
            child: Card(
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.account_circle_outlined,
                  title: l10n.accountAndSync,
                  onTap: () => _push(context, const SettingsAccountPage()),
                ),
                _tile(
                  context,
                  icon: Icons.cloud_outlined,
                  title: l10n.storageAndBackup,
                  onTap: () => _push(context, const SettingsStoragePage()),
                ),
                _tile(
                  context,
                  icon: Icons.notifications_outlined,
                  title: l10n.notificationsAndPermissions,
                  onTap: () => _push(context, const SettingsNotificationsPage()),
                ),
                _tile(
                  context,
                  icon: Icons.palette_outlined,
                  title: l10n.appearanceAndTheme,
                  onTap: () => _push(context, const SettingsAppearancePage()),
                ),
                _tile(
                  context,
                  icon: Icons.info_outline,
                  title: l10n.about,
                  onTap: () => _push(context, const SettingsAboutPage()),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  /// 顶部：应用 Logo + 名称。
  Widget _buildHeaderCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Image.asset(
                'assets/icon/pho_icon.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pho',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.onboardingWelcomeDesc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// HyperOS 风格分组标题：灰色小字，置于卡片上方。
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

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 26),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

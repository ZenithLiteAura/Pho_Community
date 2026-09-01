import 'package:flutter/material.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/choose_album_route.dart';
import 'package:img_syncer/settings/settings_sync.dart';

/// 二级页：账户与同步 —— 本地相册 + 同步设置入口。
class SettingsAccountPage extends StatelessWidget {
  const SettingsAccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountAndSync)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Card(
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.folder_outlined,
                  title: l10n.localFolder,
                  onTap: () => _push(context, const ChooseAlbumRoute()),
                ),
                _tile(
                  context,
                  icon: Icons.cloud_sync_outlined,
                  title: l10n.syncSettings,
                  onTap: () => _push(context, const SettingsSyncPage()),
                ),
              ],
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

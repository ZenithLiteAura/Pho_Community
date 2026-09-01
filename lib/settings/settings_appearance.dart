import 'package:flutter/material.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/settings/settings_theme.dart';
import 'package:img_syncer/settings/settings_dark_mode.dart';
import 'package:img_syncer/settings/settings_dock.dart';
import 'package:img_syncer/settings/settings_gallery_columns.dart';

/// 二级页：外观与主题 —— 4 个标题入口，具体配置全部在三级页中完成。
class SettingsAppearancePage extends StatelessWidget {
  const SettingsAppearancePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appearanceAndTheme)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Card(
            child: Column(
              children: [
                _titleTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: l10n.themeStyle,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsThemePage(),
                    ),
                  ),
                ),
                _titleTile(
                  context,
                  icon: Icons.dark_mode_outlined,
                  title: l10n.darkMode,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsDarkModePage(),
                    ),
                  ),
                ),
                _titleTile(
                  context,
                  icon: Icons.layers_outlined,
                  title: 'Dock 设置',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsDockPage(),
                    ),
                  ),
                ),
                _titleTile(
                  context,
                  icon: Icons.grid_view_outlined,
                  title: l10n.galleryColumnCount,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsGalleryColumnsPage(),
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

  /// 标题-only tile：只显示图标 + 标题 + 右箭头，无副标题、无状态预览。
  Widget _titleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 26),
      title: Text(title),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
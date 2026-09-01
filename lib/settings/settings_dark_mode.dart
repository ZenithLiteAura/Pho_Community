import 'package:flutter/material.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/settings/theme_controller.dart';

/// 三级页：深色模式 —— 浅色 / 深色 / 跟随系统 单选，所见即所选。
class SettingsDarkModePage extends StatelessWidget {
  const SettingsDarkModePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.darkMode)),
      body: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              Card(
                child: Column(
                  children: [
                    RadioListTile<PhoDarkMode>(
                      title: Text(l10n.darkModeLight),
                      value: PhoDarkMode.light,
                      groupValue: themeController.darkMode,
                      onChanged: (v) {
                        if (v != null) themeController.setDarkMode(v);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<PhoDarkMode>(
                      title: Text(l10n.darkModeDark),
                      value: PhoDarkMode.dark,
                      groupValue: themeController.darkMode,
                      onChanged: (v) {
                        if (v != null) themeController.setDarkMode(v);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<PhoDarkMode>(
                      title: Text(l10n.darkModeSystem),
                      value: PhoDarkMode.system,
                      groupValue: themeController.darkMode,
                      onChanged: (v) {
                        if (v != null) themeController.setDarkMode(v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
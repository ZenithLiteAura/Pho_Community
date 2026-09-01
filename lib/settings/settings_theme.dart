import 'package:flutter/material.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/settings/theme_controller.dart';

/// 三级页：主题风格 —— MIUIX / Material 3 单选，所见即所选。
class SettingsThemePage extends StatelessWidget {
  const SettingsThemePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeStyle)),
      body: ListenableBuilder(
        listenable: themeController,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              Card(
                child: Column(
                  children: [
                    RadioListTile<PhoThemeMode>(
                      title: Text(l10n.themeMiuix),
                      subtitle: Text(
                        l10n.themeMiuixDesc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      value: PhoThemeMode.miuix,
                      groupValue: themeController.mode,
                      onChanged: (v) {
                        if (v != null) themeController.setMode(v);
                      },
                    ),
                    const Divider(height: 1),
                    RadioListTile<PhoThemeMode>(
                      title: Text(l10n.themeMaterial3),
                      subtitle: Text(
                        l10n.themeMaterial3Desc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      value: PhoThemeMode.material3,
                      groupValue: themeController.mode,
                      onChanged: (v) {
                        if (v != null) themeController.setMode(v);
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
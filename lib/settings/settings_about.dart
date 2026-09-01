import 'package:flutter/material.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';

/// 二级页：关于 —— 应用 Logo、名称、版本与作者。
class SettingsAboutPage extends StatelessWidget {
  const SettingsAboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: Image.asset(
                'assets/icon/pho_icon.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              'Pho',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              l10n.onboardingWelcomeDesc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, size: 26),
                  title: Text(l10n.appVersion),
                  subtitle: Text(
                    'Pho - 3.1',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline, size: 26),
                  title: Text('Author'),
                  subtitle: Text(
                    'ZenithLiteAura',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

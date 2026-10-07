import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:img_syncer/app/pages/settings/settings_advanced.dart';
import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/state/update_checker.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/liquid_glass_toast.dart';
import 'package:img_syncer/app/widgets/update_dialog.dart';

/// 二级页：关于 —— 应用 Logo、名称、版本、原作者、社区发行版、许可证与更新检查。
///
/// 本页同时是社区发行版的「适当法律声明」入口（GPL-3.0）：
/// 展示版权、原作者、修改说明与许可证，并提供
/// 「高级设置 → 关闭启动前弹窗」的入口。
class SettingsAboutPage extends StatefulWidget {
  const SettingsAboutPage({Key? key}) : super(key: key);

  @override
  State<SettingsAboutPage> createState() => _SettingsAboutPageState();
}

class _SettingsAboutPageState extends State<SettingsAboutPage> {
  /// 是否正在检查更新（用于按钮转圈与防重复点击）。
  bool _checking = false;

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // 无浏览器或无法打开时忽略：链接文本在页面中可见，可长按复制。
    }
  }

  void _pushAdvanced() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsAdvancedPage()),
    );
  }

  /// 手动检查更新：有新版弹「发现新版本」，否则用提示条告知结果。
  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final result = await checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);

    if (result.hasUpdate) {
      await showUpdateAvailableDialog(context, result.release!);
      return;
    }
    if (!mounted) return;
    LiquidGlassToast.show(
      context,
      result.ok ? l10n.updateLatest : l10n.updateCheckFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
              communityAppName,
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              l10n.onboardingWelcomeDesc,
              style: textTheme.bodySmall?.copyWith(
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
                    '$communityAppName - $communityVersion',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  isThreeLine: true,
                  leading: const Icon(Icons.person_outline, size: 26),
                  title: Text(l10n.aboutOriginalAuthor),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        originalAuthor,
                        style: TextStyle(color: colorScheme.primary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        originalAuthorRepo,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _openUrl(originalAuthorRepo),
                ),
                const Divider(height: 1),
                ListTile(
                  isThreeLine: true,
                  leading: const Icon(Icons.groups_outlined, size: 26),
                  title: Text(l10n.aboutCommunityBuild),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        communityMaintainer,
                        style: TextStyle(color: colorScheme.primary),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        communityRepo,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _openUrl(communityRepo),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined, size: 26),
                  title: Text(l10n.aboutLicense),
                  subtitle: Text(
                    licenseName,
                    style: TextStyle(color: colorScheme.primary),
                  ),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _openUrl(licenseUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt_outlined, size: 26),
                  title: Text(l10n.checkForUpdate),
                  subtitle: Text(
                    _checking ? l10n.checkingUpdate : l10n.checkForUpdateDesc,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                  onTap: _checking ? null : _checkUpdate,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune_outlined, size: 26),
                  title: Text(l10n.advancedSettings),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: _pushAdvanced,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(
              '© 2026 $originalAuthor  |  '
              'GPL-3.0  |  '
              '$communityModifiedDate 由 $communityMaintainer 修改并发布',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

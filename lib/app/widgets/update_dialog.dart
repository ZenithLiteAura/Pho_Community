import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/state/update_checker.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 启动时自动检查更新。
///
/// 仅在**确实存在新版本**时弹窗；其余情况（已是最新、用户关闭了自动检查、
/// 网络失败、无 Release）全部静默，绝不打扰用户，也绝不影响启动流程。
Future<void> autoCheckForUpdateAndNotify(BuildContext context) async {
  var disabled = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    disabled = prefs.getBool(autoUpdateCheckPrefKey) ?? false;
  } catch (_) {
    disabled = false;
  }
  if (disabled || !context.mounted) return;

  final result = await checkForUpdate();
  if (!context.mounted || !result.hasUpdate) return;
  await showUpdateAvailableDialog(context, result.release!);
}

/// 弹出「发现新版本」提示。
Future<void> showUpdateAvailableDialog(
    BuildContext context, AppRelease release) {
  return showDialog<void>(
    context: context,
    builder: (_) => UpdateAvailableDialog(release: release),
  );
}

/// 「发现新版本」弹窗：展示版本号/更新说明，并提供前往下载入口。
class UpdateAvailableDialog extends StatelessWidget {
  const UpdateAvailableDialog({Key? key, required this.release})
      : super(key: key);

  final AppRelease release;

  Future<void> _openDownload() async {
    try {
      await launchUrl(
        Uri.parse(release.htmlUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // 无法打开浏览器时忽略：地址在弹窗中可选中复制。
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final notes = release.body.trim();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_alt, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(l10n.updateAvailableTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$communityAppName ${release.version ?? release.tag}',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.updateAvailableBody,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              release.htmlUrl,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.updateReleaseNotes,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(notes, style: textTheme.bodySmall),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.updateLater),
        ),
        FilledButton(
          onPressed: _openDownload,
          child: Text(l10n.updateGoDownload),
        ),
      ],
    );
  }
}

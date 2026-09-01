import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:extended_image/extended_image.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/settings/backup_manager.dart';

/// 二级页：数据管理 —— 备份、恢复、清除缓存。
class SettingsDataManagementPage extends StatelessWidget {
  const SettingsDataManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataManagement)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _sectionHeader(context, l10n.backupRestore),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                  child: Text(
                    l10n.backupDesc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            onPressed: () => _backup(context),
                            icon: const Icon(Icons.settings_backup_restore, size: 20),
                            label: Text(l10n.backupToFile),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _restore(context),
                            icon: const Icon(Icons.restore, size: 20),
                            label: Text(l10n.restoreFromBackup),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, size: 26),
                  title: Text(l10n.clearCache),
                  subtitle: Text(
                    l10n.clearCacheDescription,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _showClearCacheDialog(context),
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

  Future<void> _backup(BuildContext context) async {
    try {
      final bytes = await BackupManager.createBackup();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.backupToFile,
        fileName: 'pho-backup-$stamp.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: bytes,
      );
      if (path != null) {
        SnackBarManager.showSnackBar('${l10n.backupSuccess}: $path');
      }
    } catch (e) {
      SnackBarManager.showSnackBar('${l10n.backupFailed}: $e');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreFromBackup),
        content: Text(l10n.restoreConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        SnackBarManager.showSnackBar(l10n.noBackupFile);
        return;
      }
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        await BackupManager.restore(bytes);
      } else {
        final fp = result.files.single.path;
        if (fp == null) {
          SnackBarManager.showSnackBar(l10n.noBackupFile);
          return;
        }
        await BackupManager.restore(await File(fp).readAsBytes());
      }
      SnackBarManager.showSnackBar(l10n.restoreSuccess);
    } catch (e) {
      SnackBarManager.showSnackBar('${l10n.restoreFailed}: $e');
    }
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.fromLTRB(30, 20, 20, 5),
              child: Text(l10n.clearCache,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(30, 5, 20, 5),
              child: Text(l10n.clearCacheDescription),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    clearDiskCachedImages();
                    PhotoManager.clearFileCache();
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.yes),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

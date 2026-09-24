import 'package:flutter/material.dart';

import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/pages/storage_config_page.dart';
import 'package:img_syncer/app/pages/settings/settings_data_management.dart';

/// 二级页：存储与备份 —— 主存储配置 + 数据管理入口。
///
/// v3.3 起主存储复用 [StorageConfigBody]（协议选择 SMB / WebDAV / NFS +
/// 对应协议表单），不再自建 WebDAV 专用表单：
///  - 三种协议与 WebDAV 主备双存储全部保留，功能无损失；
///  - `drive` 由所选协议表单在「保存」时写入，不再被硬编码成 WebDAV，
///    修掉「SMB/NFS 用户进本页误点保存 → drive 变 WebDAV 而 webdav_url 为空
///    → initDrive 不再装载任何驱动、存储整体失效」的问题。
class SettingsStoragePage extends StatelessWidget {
  const SettingsStoragePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storageAndBackup)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // ── 主存储：协议选择 + 对应协议表单（表单自带「测试存储 / 保存」） ──
          _sectionHeader(context, l10n.primaryStorage),
          const Padding(
            // 与设置树其他页面的默认 Card 边距（4）对齐
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: StorageConfigBody(),
          ),
          // ── 数据管理 ──
          _sectionHeader(context, l10n.dataManagement),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_zip_outlined, size: 26),
              title: Text(l10n.dataManagement),
              subtitle: Text(
                l10n.backupRestore,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsDataManagementPage(),
                ),
              ),
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
              color: AppColors.primary,
              letterSpacing: 0.05,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/storageform/smbform.dart';
import 'package:img_syncer/app/widgets/storageform/webdavform.dart';
import 'package:img_syncer/app/widgets/storageform/nfsform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/app/state/state_model.dart';
import 'package:img_syncer/app/state/global.dart';

/// 存储配置主体：协议选择器 + 所选协议的表单。
///
/// 这是**唯一**的存储配置实现，三个外壳复用它，避免重复实现：
///  - [StorageConfigPage]：独立路由页（桌面端入口）
///  - `_StorageFormPage`（引导流程）：嵌套路由的 body
///  - `SettingsStoragePage`（设置树「存储与备份」）：主存储卡片
///
/// 本组件不持有任何存储字段：字段读写与「测试存储 / 保存」按钮全部由各协议
/// 表单（SMBForm / WebDavForm / NFSForm）负责，它们保存时会写回**自己的**
/// `drive` 值。因此本组件切换协议时只改内存中的 UI 状态、不落盘，
/// 避免"只切下拉框未保存"就把已配置的 drive 覆盖成空配置而让存储失效。
class StorageConfigBody extends StatefulWidget {
  const StorageConfigBody({Key? key}) : super(key: key);

  @override
  StorageConfigBodyState createState() => StorageConfigBodyState();
}

class StorageConfigBodyState extends State<StorageConfigBody> {
  @protected
  Drive currentDrive = Drive.smb;

  @override
  void initState() {
    super.initState();
    // 以已保存的 drive 为准初始化选择器，未保存过时默认 SMB。
    SharedPreferences.getInstance().then((prefs) {
      final drive = prefs.getString("drive");
      if (drive != null && mounted) {
        setState(() {
          currentDrive = getDrive(drive);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    late Widget form;
    switch (currentDrive) {
      case Drive.smb:
        form = const SMBForm();
        break;
      case Drive.webDav:
        form = const WebDavForm();
        break;
      case Drive.nfs:
        form = const NFSForm();
        break;
      default:
        form = const Text('Not implemented');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 存储协议选择卡片 ──
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
          ),
          color: colorScheme.surfaceContainerLowest, // surfacePrimary white
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.storageProtocol,
                  style: textTheme.titleLarge?.copyWith(
                    fontFamily: AppFonts.body, // Inter
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: DropdownButtonFormField<Drive>(
                    value: currentDrive,
                    decoration: InputDecoration(
                      labelText: l10n.storageProtocol,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                    ),
                    items: driveName.entries.map((entry) {
                      return DropdownMenuItem<Drive>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: textTheme.bodyLarge?.copyWith(
                            fontFamily: AppFonts.body,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (Drive? newValue) {
                      if (newValue != null) {
                        // 只切换展示的表单，不写 prefs：drive 由表单的「保存」写入，
                        // 避免未保存就改掉 drive 导致已有存储配置失效。
                        setState(() {
                          currentDrive = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 所选协议的配置表单卡片 ──
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
          ),
          color: colorScheme.surfaceContainerLowest, // surfacePrimary white
          elevation: 0,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.storageSetting} - ${driveName[currentDrive]}',
                  style: textTheme.titleLarge?.copyWith(
                    fontFamily: AppFonts.body, // Inter
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                form,
              ],
            ),
          ),
        ),

        // ── 存储位置说明卡片 ──
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
          ),
          color: colorScheme.surfaceContainerLowest, // surfacePrimary white
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.aboutStorage,
                      style: textTheme.titleLarge?.copyWith(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.storageLocationDesc,
                  style: textTheme.bodyMedium?.copyWith(
                    fontFamily: AppFonts.body,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 独立路由页：网络储存设置。内容复用 [StorageConfigBody]。
class StorageConfigPage extends StatelessWidget {
  const StorageConfigPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.storageSetting,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: AppFonts.title, // Plus Jakarta Sans
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: StorageConfigBody(),
      ),
    );
  }
}
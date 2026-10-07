import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/state/update_checker.dart';
import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';

/// 三级页：高级设置（设置 → 关于 → 高级设置）。
///
/// 目前只有一项：「关闭启动前弹窗」。开关状态持久化在
/// [startupNoticePrefKey]，默认 false（即默认每次启动都显示版权弹窗）。
class SettingsAdvancedPage extends StatefulWidget {
  const SettingsAdvancedPage({Key? key}) : super(key: key);

  @override
  State<SettingsAdvancedPage> createState() => _SettingsAdvancedPageState();
}

class _SettingsAdvancedPageState extends State<SettingsAdvancedPage> {
  /// true = 已关闭启动前弹窗。
  bool _disableStartupNotice = false;

  /// true = 已关闭「启动时自动检查更新」。
  bool _disableAutoUpdateCheck = false;

  /// true = 已关闭「启动时检查公告」。
  bool _disableAnnouncementCheck = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _disableStartupNotice = prefs.getBool(startupNoticePrefKey) ?? false;
      _disableAutoUpdateCheck =
          prefs.getBool(autoUpdateCheckPrefKey) ?? false;
      _disableAnnouncementCheck =
          prefs.getBool(announcementCheckPrefKey) ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.advancedSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _sectionHeader(context, l10n.advancedSettings),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.campaign_outlined, size: 26),
              title: Text(l10n.disableStartupNotice),
              subtitle: Text(l10n.disableStartupNoticeDesc),
              value: _disableStartupNotice,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(startupNoticePrefKey, value);
                if (!mounted) return;
                setState(() {
                  _disableStartupNotice = value;
                });
              },
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.system_update_alt_outlined, size: 26),
              title: Text(l10n.autoCheckUpdate),
              subtitle: Text(l10n.autoCheckUpdateDesc),
              value: !_disableAutoUpdateCheck,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                // 存的是「关闭」标记，默认 false（即默认开启自动检查）。
                await prefs.setBool(autoUpdateCheckPrefKey, !value);
                if (!mounted) return;
                setState(() {
                  _disableAutoUpdateCheck = !value;
                });
              },
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.campaign_outlined, size: 26),
              title: Text(l10n.announcementCheck),
              subtitle: Text(l10n.announcementCheckDesc),
              value: !_disableAnnouncementCheck,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                // 存的是「关闭」标记，默认 false（即默认开启）。
                await prefs.setBool(announcementCheckPrefKey, !value);
                if (!mounted) return;
                setState(() {
                  _disableAnnouncementCheck = !value;
                });
              },
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
}

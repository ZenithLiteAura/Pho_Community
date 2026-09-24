import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/state/state_model.dart';
import 'package:img_syncer/core/sync_timer.dart';
import 'package:img_syncer/bridge/notifications/local_notifier.dart';

/// 二级页：同步设置 —— 后台同步（启用/仅WiFi/模式/间隔/定时）+ 加密开关。
class SettingsSyncPage extends StatefulWidget {
  const SettingsSyncPage({Key? key}) : super(key: key);

  @override
  State<SettingsSyncPage> createState() => _SettingsSyncPageState();
}

class _SettingsSyncPageState extends State<SettingsSyncPage> {
  int _uploadParallelCount = 6;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _uploadParallelCount = prefs.getInt('uploadParallelCount') ?? 6;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // ── 同步性能 ──
          _sectionHeader(context, '同步性能'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.speed, size: 26),
              title: Text(l10n.parallelUploadCount),
              subtitle: Text(
                '当前: $_uploadParallelCount 路并发',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              trailing: DropdownMenu<int>(
                initialSelection: _uploadParallelCount,
                dropdownMenuEntries: [
                  for (var i = 1; i <= 10; i++)
                    DropdownMenuEntry(value: i, label: '$i'),
                ],
                onSelected: (value) async {
                  if (value == null) return;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('uploadParallelCount', value);
                  settingModel.setParallelUploadCount(value);
                  setState(() {
                    _uploadParallelCount = value;
                  });
                },
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
      ),
    );
  }

}

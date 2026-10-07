import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/miuix_dropdown.dart';
import 'package:img_syncer/app/state/state_model.dart';

/// 二级页：同步设置 —— 同步性能（并行上传数）。
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // ── 同步性能 ──
          _sectionHeader(context, '同步性能'),
          Card(
            child: MiuixDropdownTile<int>(
              leading: const Icon(Icons.speed, size: 26),
              title: l10n.parallelUploadCount,
              value: _uploadParallelCount,
              valueText: '$_uploadParallelCount',
              items: [
                for (var i = 1; i <= 10; i++)
                  MiuixDropdownItem<int>(value: i, label: '$i'),
              ],
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('uploadParallelCount', value);
                settingModel.setParallelUploadCount(value);
                if (!mounted) return;
                setState(() {
                  _uploadParallelCount = value;
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

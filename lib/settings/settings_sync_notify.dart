import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';

/// 二级页：同步通知 —— 同步完成通知开关。
class SettingsSyncNotifyPage extends StatefulWidget {
  const SettingsSyncNotifyPage({Key? key}) : super(key: key);

  @override
  State<SettingsSyncNotifyPage> createState() =>
      _SettingsSyncNotifyPageState();
}

class _SettingsSyncNotifyPageState extends State<SettingsSyncNotifyPage> {
  bool _syncCompleteNotify = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      // 默认开启（与历史行为一致）
      _syncCompleteNotify = prefs.getBool('syncCompleteNotify') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncNotify)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _sectionHeader(context, l10n.syncNotify),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined, size: 26),
              title: Text(l10n.syncCompleteNotify),
              value: _syncCompleteNotify,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('syncCompleteNotify', value);
                setState(() {
                  _syncCompleteNotify = value;
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
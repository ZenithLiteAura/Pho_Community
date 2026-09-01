import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/sync_timer.dart';
import 'package:img_syncer/notifications/local_notifier.dart';

/// 二级页：同步设置 —— 后台同步（启用/仅WiFi/模式/间隔/定时）+ 加密开关。
class SettingsSyncPage extends StatefulWidget {
  const SettingsSyncPage({Key? key}) : super(key: key);

  @override
  State<SettingsSyncPage> createState() => _SettingsSyncPageState();
}

class _SettingsSyncPageState extends State<SettingsSyncPage> {
  bool _backgroundSyncEnabled = false;
  bool _backgroundSyncWifiOnly = true;
  Duration _backgroundSyncInterval = const Duration(minutes: 60);
  String _backgroundSyncMode = 'interval';
  List<String> _backgroundSyncSchedule = [];
  bool _enableEncrypt = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _backgroundSyncEnabled = prefs.getBool('backgroundSyncEnabled') ?? false;
      _backgroundSyncWifiOnly = prefs.getBool('backgroundSyncWifiOnly') ?? true;
      _backgroundSyncInterval =
          Duration(minutes: prefs.getInt('backgroundSyncInterval') ?? 60);
      _backgroundSyncMode = prefs.getString('backgroundSyncMode') ?? 'interval';
      _backgroundSyncSchedule =
          prefs.getStringList('backgroundSyncSchedule') ?? [];
      _enableEncrypt = prefs.getBool('enable_encrypt') ?? false;
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
          // ── 后台同步 ──
          _sectionHeader(context, l10n.backgroundSync),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync_outlined, size: 26),
                  title: Text(l10n.enableBackgroundSync),
                  value: _backgroundSyncEnabled,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('backgroundSyncEnabled', value);
                    setState(() {
                      _backgroundSyncEnabled = value;
                    });
                    if (value) {
                      // 开启后台同步时请求通知权限（Android 13+ 需要）
                      await LocalNotifier.requestNotificationPermission();
                    }
                    reloadAutoSyncTimer();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi, size: 26),
                  title: Text(l10n.syncOnlyOnWifi),
                  value: _backgroundSyncWifiOnly,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('backgroundSyncWifiOnly', value);
                    setState(() {
                      _backgroundSyncWifiOnly = value;
                    });
                    reloadAutoSyncTimer();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule, size: 26),
                  title: Text(l10n.syncMode),
                  trailing: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'interval',
                        label: Text(l10n.syncModeInterval),
                      ),
                      ButtonSegment(
                        value: 'schedule',
                        label: Text(l10n.syncModeSchedule),
                      ),
                    ],
                    selected: {_backgroundSyncMode},
                    onSelectionChanged: (selection) async {
                      final value = selection.first;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('backgroundSyncMode', value);
                      setState(() {
                        _backgroundSyncMode = value;
                      });
                      reloadAutoSyncTimer();
                    },
                  ),
                ),
                if (_backgroundSyncMode == 'interval')
                  ListTile(
                    leading: const Icon(Icons.timer_outlined, size: 26),
                    title: Text(l10n.syncInterval),
                    trailing: DropdownMenu<Duration>(
                      initialSelection: _backgroundSyncInterval,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          value: const Duration(minutes: 10),
                          label: '10 ${l10n.minite}',
                        ),
                        DropdownMenuEntry(
                          value: const Duration(hours: 1),
                          label: '1 ${l10n.hour}',
                        ),
                        DropdownMenuEntry(
                          value: const Duration(hours: 3),
                          label: '3 ${l10n.hour}',
                        ),
                        DropdownMenuEntry(
                          value: const Duration(hours: 6),
                          label: '6 ${l10n.hour}',
                        ),
                        DropdownMenuEntry(
                          value: const Duration(hours: 12),
                          label: '12 ${l10n.hour}',
                        ),
                        DropdownMenuEntry(
                          value: const Duration(days: 1),
                          label: '1 ${l10n.day}',
                        ),
                        DropdownMenuEntry(
                          value: const Duration(days: 3),
                          label: '3 ${l10n.day}',
                        ),
                        DropdownMenuEntry(
                          value: const Duration(days: 7),
                          label: '1 ${l10n.week}',
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == null) return;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt(
                            'backgroundSyncInterval', value.inMinutes);
                        setState(() {
                          _backgroundSyncInterval = value;
                        });
                        reloadAutoSyncTimer();
                      },
                    ),
                  ),
                if (_backgroundSyncMode == 'schedule')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.scheduledSyncTimes,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addScheduleTime,
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(l10n.addTime),
                            ),
                          ],
                        ),
                        if (_backgroundSyncSchedule.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm),
                            child: Text(
                              l10n.noScheduleTimes,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: colorScheme.onSurfaceVariant),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final t in _backgroundSyncSchedule)
                                InputChip(
                                  label: Text(t),
                                  onDeleted: () => _removeScheduleTime(t),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ── 加密 ──
          _sectionHeader(context, l10n.encryption),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.lock_outline, size: 26),
              title: Text(l10n.encryption),
              value: _enableEncrypt,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('enable_encrypt', value);
                settingModel.setEncryptSwitch(value);
                setState(() {
                  _enableEncrypt = value;
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

  Future<void> _addScheduleTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final hhmm =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final updated = {..._backgroundSyncSchedule, hhmm}.toList()..sort();
    setState(() {
      _backgroundSyncSchedule = updated;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('backgroundSyncSchedule', updated);
    reloadAutoSyncTimer();
  }

  Future<void> _removeScheduleTime(String time) async {
    final updated = [..._backgroundSyncSchedule]..remove(time);
    setState(() {
      _backgroundSyncSchedule = updated;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('backgroundSyncSchedule', updated);
    reloadAutoSyncTimer();
  }
}

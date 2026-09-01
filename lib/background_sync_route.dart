import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:img_syncer/sync_timer.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/notifications/local_notifier.dart';
import 'package:img_syncer/design_tokens.dart';

class BackgroundSyncSettingRoute extends StatefulWidget {
  const BackgroundSyncSettingRoute({Key? key}) : super(key: key);

  @override
  _BackgroundSyncSettingRouteState createState() =>
      _BackgroundSyncSettingRouteState();
}

class _BackgroundSyncSettingRouteState
    extends State<BackgroundSyncSettingRoute> {
  bool _backgroundSyncEnabled = false;
  bool _backgroundSyncWifiOnly = true;
  Duration _backgroundSyncInterval = const Duration(minutes: 60);
  int _uploadParallelCount = 3;
  String _backgroundSyncMode = 'interval';
  List<String> _backgroundSyncSchedule = [];
  List<AssetPathEntity> albums = [];
  bool _notificationDenied = false;
  int _backgroundRefreshStatus = 2; // 0=restricted, 1=denied, 2=available

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundSyncEnabled = prefs.getBool('backgroundSyncEnabled') ?? false;
      _backgroundSyncWifiOnly = prefs.getBool('backgroundSyncWifiOnly') ?? true;
      _backgroundSyncInterval =
          Duration(minutes: prefs.getInt('backgroundSyncInterval') ?? 60);
      _uploadParallelCount = prefs.getInt('uploadParallelCount') ?? 3;
      _backgroundSyncMode = prefs.getString('backgroundSyncMode') ?? 'interval';
      _backgroundSyncSchedule =
          prefs.getStringList('backgroundSyncSchedule') ?? [];
    });
    if (Platform.isIOS && _backgroundSyncEnabled) {
      final granted = await LocalNotifier.checkAuthorizationStatus();
      if (mounted) {
        setState(() {
          _notificationDenied = !granted;
        });
      }
    }
    if (Platform.isIOS) {
      try {
        final result = await const MethodChannel('com.example.img_syncer/notifications')
            .invokeMethod('getBackgroundRefreshStatus');
        if (mounted) {
          setState(() {
            _backgroundRefreshStatus = result as int;
          });
        }
      } catch (_) {
        // 非 iOS 平台或 channel 未注册时忽略
      }
    }
    final re = await requestPermission();
    if (!re) return;
    albums = await PhotoManager.getAssetPathList(type: RequestType.common);
    for (var path in albums) {
      if (path.name == 'Recent') {
        albums.remove(path);
        break;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: Theme.of(context).iconTheme,
        elevation: 0,
        title: Text(l10n.backgroundSync,
            style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView(
        children: [
          if (Platform.isIOS)
            Card(
              margin: const EdgeInsets.all(AppSpacing.paddingStandard),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.paddingStandard),
                child: Text(
                  l10n.iosBackgroundSyncDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (Platform.isIOS && _backgroundRefreshStatus != 2)
            Card(
              margin: const EdgeInsets.all(AppSpacing.paddingStandard),
              color: Theme.of(context).colorScheme.errorContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.paddingStandard),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.backgroundRefreshDisabledTitle,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.backgroundRefreshDisabledDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          launchUrl(Uri.parse('app-settings:'));
                        },
                        icon: Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        label: Text(l10n.backgroundRefreshDisabledAction),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ListTile(
            title: Text(l10n.enableBackgroundSync),
            trailing: Switch(
              value: _backgroundSyncEnabled,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('backgroundSyncEnabled', value);
                setState(() {
                  _backgroundSyncEnabled = value;
                });
                if (value && Platform.isIOS) {
                  final granted =
                      await LocalNotifier.requestNotificationPermission();
                  if (!granted) {
                    // 不阻止 enable，但记录拒绝状态供后续 banner 显示
                  }
                  if (mounted) {
                    setState(() {
                      _notificationDenied = !granted;
                    });
                  }
                }
                reloadAutoSyncTimer();
              },
            ),
          ),
          ListTile(
            title: Text(l10n.syncOnlyOnWifi),
            trailing: Switch(
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
          ),
          ListTile(
            title: Text(l10n.parallelUploadCount),
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
                setState(() {
                  _uploadParallelCount = value;
                });
                settingModel.setParallelUploadCount(value);
              },
            ),
          ),
          if (!Platform.isIOS)
            ListTile(
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
          if (!Platform.isIOS && _backgroundSyncMode == 'schedule')
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.paddingStandard,
                  0,
                  AppSpacing.paddingStandard,
                  AppSpacing.sm),
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
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Text(
                        l10n.noScheduleTimes,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
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
          if (!Platform.isIOS && _backgroundSyncMode == 'interval')
            ListTile(
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
                await prefs.setInt('backgroundSyncInterval', value.inMinutes);
                setState(() {
                  _backgroundSyncInterval = value;
                });
                reloadAutoSyncTimer();
              },
            ),
          ),
          if (Platform.isIOS && _backgroundSyncEnabled && _notificationDenied)
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.notificationDenied,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
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

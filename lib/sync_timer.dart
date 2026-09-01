import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/sync/background_runner.dart';
import 'package:img_syncer/sync/bg_task_scheduler.dart';
import 'package:img_syncer/notifications/local_notifier.dart';

Timer? autoSyncTimer;

/// 解析 "HH:mm" 字符串为 [day] 当天对应时刻；格式非法时返回 null。
DateTime? parseScheduleTime(String hhmm, DateTime day) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// 计算下一次定时同步时刻：
/// - 取今天尚未过去的定时点中最早的一个；
/// - 若今天全部已过（或今天没有），取明天最早的一个；
/// - [schedule] 为空或全部非法时返回 null。
DateTime? nextScheduleOccurrence(List<String> schedule, DateTime now) {
  if (schedule.isEmpty) return null;
  final todayTimes = <DateTime>[];
  for (final s in schedule) {
    final t = parseScheduleTime(s, now);
    if (t != null) todayTimes.add(t);
  }
  if (todayTimes.isEmpty) return null;
  todayTimes.sort();
  for (final t in todayTimes) {
    if (t.isAfter(now)) return t;
  }
  // 今天全部已过：取明天最早的定时点
  final tomorrow =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final tomorrowTimes = <DateTime>[];
  for (final s in schedule) {
    final t = parseScheduleTime(s, tomorrow);
    if (t != null) tomorrowTimes.add(t);
  }
  tomorrowTimes.sort();
  return tomorrowTimes.isEmpty ? null : tomorrowTimes.first;
}

/// 执行一次自动（后台）同步，间隔模式与定时模式共用。
/// 读取 prefs 中的 wifi-only 与并行上传数配置。
Future<void> performAutoSync() async {
  final prefs = await SharedPreferences.getInstance();
  if (settingModel.localFolder == "" || !settingModel.isRemoteStorageSetted) {
    return;
  }
  final wifiOnly = prefs.getBool('backgroundSyncWifiOnly') ?? true;
  if (wifiOnly) {
    final results = await Connectivity().checkConnectivity();
    if (!results.contains(ConnectivityResult.wifi)) {
      return;
    }
  }
  if (stateModel.isUploading() || stateModel.isDownloading()) return;
  // 仅首次（无本地已同步缓存）才与服务器比对未同步列表；
  // 之后直接使用本地缓存的 syncedIDs 增量同步，避免每次启动都从服务器
  // 重新获取、也避免服务器比对结果覆盖本地记录导致已上传照片被重复上传。
  // 需要重新比对时，可在同步页手动点击「刷新未同步照片」。
  final needServerCompare = stateModel.syncedIDs.isEmpty ||
      stateModel.lastRefreshUnsyncTime == null;
  if (needServerCompare) {
    await refreshUnsynchronizedPhotos();
  } else {
    print(
        "auto sync: using local synced cache (${stateModel.syncedIDs.length} ids), skip server compare");
  }
  final Map<String, bool> uploadedIds = {};
  for (final id in stateModel.syncedIDs) {
    uploadedIds[id] = true;
  }
  final entities = await getPhotos();
  final all = entities.map((e) => Asset(local: e)).toList();
  // 重置中断标志：后台定时同步独立于手动 sync 的 stop 状态。
  stateModel.needStopSync = false;
  final parallelCount = prefs.getInt('uploadParallelCount') ?? 6;
  // 过滤逻辑（视频/图片跳过、日期边界、扩展名白名单）由 runSyncOnce
  // 内部调用 shouldSyncAsset 统一处理，替代原 sync_timer 内联 if 过滤段。
  // 行为变更：日期上界从原 +1day 宽限对齐为 canonical（无 offset）；
  // 新增按扩展名白名单过滤（原内联段无此检查）。
  final result = await runSyncOnce(
    storage: storageClient,
    assets: all,
    uploadedIds: uploadedIds,
    parallelCount: parallelCount > 0 ? parallelCount : 1,
    shouldStop: () => stateModel.needStopSync,
    refreshUnSync: true,
  );
  // 后台同步完成通知（成功数为 0 时静默不发）
  await LocalNotifier.sendSyncCompleteNotification(
    succeeded: result.succeeded,
    failed: result.failed,
  );
}

Future<void> reloadAutoSyncTimer() async {
  if (autoSyncTimer != null) {
    autoSyncTimer!.cancel();
  }
  // iOS 不使用 Timer.periodic：由系统 BGProcessingTask 调度后台同步。
  // 但仍需读 backgroundSyncEnabled：用户未开后台同步时不提交 BG task，
  // 与 Android 路径行为一致（避免每次启动都无条件 schedule）。
  // scheduleBgTaskViaChannel 内部已捕获异常，模拟器上的 .unavailable 不会冒泡。
  if (Platform.isIOS) {
    final prefs = await SharedPreferences.getInstance();
    final backgroundSyncEnable =
        prefs.getBool('backgroundSyncEnabled') ?? false;
    if (!backgroundSyncEnable) return;
    await scheduleBgTaskViaChannel();
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final backgroundSyncEnable = prefs.getBool('backgroundSyncEnabled') ?? false;
  if (!backgroundSyncEnable) return;

  // 定时模式：按用户设定的每日时间点触发（可多个）。
  final syncMode = prefs.getString('backgroundSyncMode') ?? 'interval';
  if (syncMode == 'schedule') {
    final schedule = prefs.getStringList('backgroundSyncSchedule') ?? [];
    final next = nextScheduleOccurrence(schedule, DateTime.now());
    if (next == null) {
      print("auto sync: schedule list is empty or invalid, no timer");
      return;
    }
    final delay = next.difference(DateTime.now());
    print("auto sync scheduled at: $next");
    autoSyncTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      print("start scheduled auto sync");
      await performAutoSync();
      // 完成一轮后重新装载定时器，等待下一个定时点。
      reloadAutoSyncTimer();
    });
    return;
  }

  final backgroundSyncInterval =
      Duration(minutes: prefs.getInt('backgroundSyncInterval') ?? 60 * 12);
  print("backgroundSyncInterval: $backgroundSyncInterval");
  autoSyncTimer = Timer.periodic(backgroundSyncInterval, (timer) async {
    print("start auto sync");
    await performAutoSync();
  });
}

Future<List<AssetEntity>> getPhotos() async {
  List<AssetEntity> all = [];
  final re = await requestPermission();
  if (!re) return all;
  final List<AssetPathEntity> paths =
      await PhotoManager.getAssetPathList(type: RequestType.common);
  for (var path in paths) {
    if (path.name == settingModel.localFolder) {
      final newpath = await path.fetchPathProperties(
          filterOptionGroup: FilterOptionGroup(
        orders: [
          const OrderOption(
            type: OrderOptionType.createDate,
            asc: false,
          ),
        ],
      ));
      int assetOffset = 0;
      int assetPageSize = 100;
      while (true) {
        final List<AssetEntity> assets = await newpath!.getAssetListRange(
            start: assetOffset, end: assetOffset + assetPageSize);
        if (assets.isEmpty) {
          break;
        }
        all.addAll(assets);
        assetOffset += assetPageSize;
      }
      break;
    }
  }
  return all;
}
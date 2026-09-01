import 'dart:async';

import 'package:async_locks/async_locks.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage_interface.dart';
import 'package:path/path.dart';

/// 一次同步的汇总结果。
class SyncResult {
  final int succeeded;
  final int failed;
  final int total;
  final Duration duration;
  /// key = assetId, value = error.toString()
  final Map<String, String> failures;

  const SyncResult({
    required this.succeeded,
    required this.failed,
    required this.total,
    required this.duration,
    required this.failures,
  });
}

/// UI 副作用回调（可选）。background_runner 本身不触碰 UI；
/// 调用方（sync_body / sync_timer）通过此回调驱动 UI / 状态更新。
class SyncCallbacks {
  /// 进度回调：(completed, total, failed)。
  final void Function(int completed, int total, int failed)? onProgress;

  /// 单张资产上传失败回调：(assetId, error)。
  final void Function(String assetId, String error)? onAssetFailed;

  const SyncCallbacks({this.onProgress, this.onAssetFailed});
}

/// 统一的同步判定：同步的三个位置（计数、上传、展示）必须使用相同逻辑。
/// 提取为顶层函数以便测试与跨调用方复用（sync_body / sync_timer / background_runner）。
/// 开源版仅检查是否已上传；Pro 版过滤逻辑已移除。
bool shouldSyncAsset(
    Asset asset, String id, Map<String, bool> uploadedIds, String extensionStr) {
  if (uploadedIds[id] == true) {
    return false;
  }
  return true;
}

/// 执行一次同步。纯逻辑，无 UI 副作用（无 setState / keepScreenOn / SnackBar / mounted 检查）。
///
/// [storage] 上传客户端（测试可注入 mock，通过 storageClient getter 注入）。
/// [assets] 待同步的本地资产列表。
/// [uploadedIds] 已上传 ID 集合（O(1) 查重），不会被本函数原地修改。
/// [parallelCount] 并发上传数。
/// [callbacks] 可选的 UI 回调（进度 / 单张失败）。
/// [shouldStop] 中断检查回调，返回 true 时尽快停止当前同步轮。
/// [refreshUnSync] 结束时 fire 的 RemoteRefreshEvent.refreshUnSync 标志，
///   sync_body 传 false（仅刷新远端列表），sync_timer 传 true（还刷新未同步集合）。
///
/// 完成时调用 stateModel.saveSyncedIDs() 持久化并通过 eventBus 广播刷新事件。
Future<SyncResult> runSyncOnce({
  required RemoteStorageClient storage,
  required List<Asset> assets,
  required Map<String, bool> uploadedIds,
  required int parallelCount,
  SyncCallbacks? callbacks,
  required bool Function() shouldStop,
  bool refreshUnSync = false,
}) async {
  final startTime = DateTime.now();
  final Map<String, String> failures = {};
  int failedTimes = 0;
  int completed = 0;
  int failed = 0;

  // 第一遍：计算待同步总数（与 sync 原实现一致，两遍循环均调用 shouldSyncAsset）。
  int total = 0;
  for (var asset in assets) {
    final ext = extension(await asset.name());
    if (shouldSyncAsset(asset, asset.local!.id, uploadedIds, ext)) {
      total++;
    }
  }

  callbacks?.onProgress?.call(completed, total, failed);

  final sem = Semaphore(parallelCount);
  for (var asset in assets) {
    if (shouldStop()) {
      break;
    }
    // 连续失败超阈值即中止（原 SnackBar 通知由调用方负责，此处仅 break）。
    if (failedTimes > 10) {
      break;
    }
    final ext = extension(await asset.name());
    final localId = asset.local!.id;
    if (!shouldSyncAsset(asset, localId, uploadedIds, ext)) {
      continue;
    }
    await sem.acquire();
    // v2.2 修复：acquire 后再次检查停止信号。
    // 若已停止，立即释放 permit 并跳出外层循环，
    // 避免「permit 占用但任务未提交」的伪死锁现象。
    if (shouldStop()) {
      sem.release();
      break;
    }
    unawaited(
      storage.uploadAssetEntity(asset.local!).then((_) {
        if (failedTimes > 0) {
          failedTimes--;
        }
        completed++;
        callbacks?.onProgress?.call(completed, total, failed);
        sem.release();
      }).catchError((e) {
        failedTimes++;
        completed++;
        failed++;
        failures[localId] = e.toString();
        callbacks?.onAssetFailed?.call(localId, e.toString());
        callbacks?.onProgress?.call(completed, total, failed);
        logger.addLog('uploadAssetEntity failed: $e');
        sem.release();
      }),
    );
  }
  // 等待所有在途任务完成：获取全部permit（sem 为局部对象，随后GC，无需release）。
  // v2.2 改进：停止信号一来，跳过等待，立即返回当前进度，
  // 让 UI 立刻感受到「已停止」（已在 UI 层处理 toast/FAB 反馈）。
  if (!shouldStop()) {
    for (var i = 0; i < parallelCount; i++) {
      await sem.acquire();
    }
  }

  await stateModel.saveSyncedIDs();
  eventBus.fire(RemoteRefreshEvent(refreshUnSync: refreshUnSync));

  return SyncResult(
    succeeded: completed - failed,
    failed: failed,
    total: total,
    duration: DateTime.now().difference(startTime),
    failures: failures,
  );
}
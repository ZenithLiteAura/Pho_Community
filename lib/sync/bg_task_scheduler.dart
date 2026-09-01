import 'package:flutter/services.dart';

/// 通过 platform channel 调度 iOS BGProcessingTask。
///
/// 在 headless entrypoint 与 UI 层共用：iOS 上 `reloadAutoSyncTimer()` 不再创建
/// `Timer.periodic`，而是调用本函数向系统提交 `BGProcessingTaskRequest`，由系统
/// 在合适的时机唤醒应用执行后台同步。
///
/// Android 端不走此路径，仍使用 `Timer.periodic` 轮询。
///
/// 失败时仅记录日志、不抛异常：
/// - iOS 模拟器上 BGTaskScheduler 恒抛 `unavailable`，平台限制
/// - 真机上 backgroundRefreshStatus 受限或系统调度失败也属于非致命情形
/// 避免启动期 reloadAutoSyncTimer 的 unhandled exception 打断应用初始化。
Future<void> scheduleBgTaskViaChannel() async {
  try {
    await const MethodChannel('com.example.img_syncer/notifications')
        .invokeMethod('scheduleBgTask');
  } catch (e) {
    print('[bgTaskScheduler] scheduleBgTask failed: $e');
  }
}

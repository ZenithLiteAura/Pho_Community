import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/global.dart';

/// iOS 后台同步本地通知封装。
///
/// 通过 platform channel `com.example.img_syncer/notifications` 与 native 端
/// （`ios/Runner/AppDelegate.swift` 的 `registerAppChannels`）通信：
/// - `requestAuthorization` / `checkAuthorizationStatus`：查询/申请通知权限
/// - `sendLocalNotification`：投递本地通知（`isPassive: true` 对应 iOS
///   `UNNotificationInterruptionLevel.passive`，不响铃、不亮屏）
///
/// 设计约束：
/// - `succeeded == 0` 时静默不发（避免夜间后台同步无新照片时打扰用户）
/// - 不在首启自动请求权限；调用方需显式调用 [requestNotificationPermission]
/// - `l10n` 为 `global.dart` 中的全局变量，调用前须确保已通过 [initI18n] 初始化
class LocalNotifier {
  static const _channel = MethodChannel('com.example.img_syncer/notifications');

  /// 请求通知权限。返回 granted bool。
  ///
  /// native 端对应 `requestAuthorization`，调用
  /// `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge])`。
  /// 返回 true 表示用户授权，false 表示拒绝；native 抛错时透传 [PlatformException]。
  static Future<bool> requestNotificationPermission() async {
    final result = await _channel.invokeMethod('requestAuthorization');
    return result == true;
  }

  /// 检查通知授权状态。
  ///
  /// native 端对应 `checkAuthorizationStatus`，读取
  /// `UNUserNotificationCenter.getNotificationSettings().authorizationStatus`。
  static Future<bool> checkAuthorizationStatus() async {
    final result = await _channel.invokeMethod('checkAuthorizationStatus');
    return result == true;
  }

  /// 发送同步完成通知。
  ///
  /// - [succeeded] 成功上传张数；== 0 时静默不发（避免每夜打扰）。
  /// - [failed] 失败张数；> 0 时使用带失败数的文案。
  /// - `isPassive: true` 让 iOS 标记为 passive interruption level。
  /// - v2.2 新增：用户可在「设置 → 通知 → 同步通知」关闭同步完成通知
  ///   （SharedPreferences key: `syncCompleteNotify`，默认 true）。
  static Future<void> sendSyncCompleteNotification({
    required int succeeded,
    required int failed,
  }) async {
    if (succeeded == 0) return;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('syncCompleteNotify') ?? true;
    if (!enabled) return;
    final title = l10n.bgSyncSuccessNotificationTitle;
    final body = failed > 0
        ? l10n.bgSyncSuccessNotificationBodyWithFailures(succeeded, failed)
        : l10n.bgSyncSuccessNotificationBody(succeeded);
    await _channel.invokeMethod('sendLocalNotification', {
      'title': title,
      'body': body,
      'isPassive': true,
    });
  }

  /// 发送同步进行中通知。
  ///
  /// 在后台同步开始时调用，让用户知道同步正在运行。
  static Future<void> sendSyncInProgressNotification() async {
    await _channel.invokeMethod('sendLocalNotification', {
      'title': l10n.bgSyncInProgressNotificationTitle,
      'body': l10n.bgSyncInProgressNotificationBody,
      'isPassive': true,
    });
  }
}

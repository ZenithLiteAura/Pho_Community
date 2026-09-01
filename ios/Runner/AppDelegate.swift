import UIKit
import Flutter
import RUN
import BackgroundTasks
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  /// 公共: 在指定 binaryMessenger 上注册 RunGrpcServer native handler
  /// foreground (FlutterViewController.binaryMessenger) 与 headless engine 两条路径共用
  private func registerAppChannels(on messenger: FlutterBinaryMessenger) {
    let runServerChannel = FlutterMethodChannel(
      name: "com.example.img_syncer/RunGrpcServer",
      binaryMessenger: messenger
    )
    runServerChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      var error: NSError? = nil
      let ports = RunRunGrpcServer(&error)
      result(ports)
    }

    // notifications channel: foreground + headless 双注册 (本函数被两处调用)
    let notificationsChannel = FlutterMethodChannel(
      name: "com.example.img_syncer/notifications",
      binaryMessenger: messenger
    )
    notificationsChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "sendLocalNotification":
        // 参数: {"title": String, "body": String, "isPassive": Bool}
        guard let args = call.arguments as? [String: Any],
              let title = args["title"] as? String,
              let body = args["body"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing title/body", details: nil))
          return
        }
        let isPassive = args["isPassive"] as? Bool ?? false
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if isPassive {
          content.interruptionLevel = .passive
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
          if let error = error {
            result(FlutterError(code: "NOTIFICATION_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(true)
          }
        }

      case "getBackgroundRefreshStatus":
        // 0=restricted, 1=denied, 2=available
        result(UIApplication.shared.backgroundRefreshStatus.rawValue)

      case "scheduleBgTask":
        let request = BGProcessingTaskRequest(identifier: "com.example.img_syncer.background-sync")
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        do {
          try BGTaskScheduler.shared.submit(request)
          result(true)
        } catch {
          result(FlutterError(code: "SCHEDULE_ERROR", message: error.localizedDescription, details: nil))
        }

      case "requestAuthorization":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          if let error = error {
            result(FlutterError(code: "AUTH_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(granted)
          }
        }

      case "checkAuthorizationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { notificationSettings in
          result(notificationSettings.authorizationStatus == .authorized)
        }

      case "keepScreenOn":
        // 直接设置 isIdleTimerDisabled，绕过 wakelock_plus 的 method swizzling（不可靠）
        guard let args = call.arguments as? [String: Any],
              let enable = args["enable"] as? Bool else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing enable", details: nil))
          return
        }
        UIApplication.shared.isIdleTimerDisabled = enable
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Apple 强制约束: BGTaskScheduler handler 必须在 application:didFinishLaunchingWithOptions: 返回前注册
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.example.img_syncer.background-sync",
      using: nil
    ) { task in
      self.handleBgSyncTask(task as! BGProcessingTask)
    }

    // 顶部分支: 后台任务启动 vs 前台启动
    // 后台路径不 touch window.rootViewController, 不创建 FlutterViewController (避免 force-unwrap crash)
    if launchOptions?[UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsBackgroundTaskSchedulerTaskIdentifierKey")] != nil {
      return true
    }

    // 前台路径 (现有逻辑, 仅将 RunGrpcServer channel 注册抽取为公共函数)
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    registerAppChannels(on: controller.binaryMessenger)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Background sync (BGProcessingTask)

  /// 处理后台同步任务:
  /// 1. 创建 headless FlutterEngine 并运行 backgroundSyncEntrypoint
  /// 2. 在 headless engine 上注册 RunGrpcServer + 全量插件
  /// 3. 通过 backgroundSync channel 与 Dart 端协商完成/取消
  /// 4. Dart 完成 -> setTaskCompleted + destroyContext
  private func handleBgSyncTask(_ task: BGProcessingTask) {
    // 1. Headless engine (不带 FlutterViewController)
    let engine = FlutterEngine(
      name: "bg-sync-engine",
      project: nil,
      allowHeadlessExecution: true
    )
    engine.run(withEntrypoint: "backgroundSyncEntrypoint",
               libraryURI: "package:img_syncer/background_sync_entrypoint.dart")

    // 2. 复用公共 channel 注册 + 全量插件注册
    //    Flutter issue #21925: headless engine 默认不自动注册插件, 需显式调用 GeneratedPluginRegistrant
    registerAppChannels(on: engine.binaryMessenger)
    GeneratedPluginRegistrant.register(with: engine)

    // 3. Dart <-> Native 协商 channel (用于 Dart 端 invokeMethod 通知完成 / cancel)
    let bgSyncChannel = FlutterMethodChannel(
      name: "com.example.img_syncer/backgroundSync",
      binaryMessenger: engine.binaryMessenger
    )

    // OS 即将强制终止任务时, 通知 Dart 端 cancel
    task.expirationHandler = {
      bgSyncChannel.invokeMethod("cancel", arguments: nil)
    }

    // 监听 Dart 端调用 complete(success:) 通知任务完成
    bgSyncChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "complete" {
        let success = (call.arguments as? Bool) ?? false
        task.setTaskCompleted(success: success)
        engine.destroyContext()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

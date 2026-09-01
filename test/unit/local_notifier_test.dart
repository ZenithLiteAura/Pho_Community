// 单测：锁住 lib/notifications/local_notifier.dart 的 channel 契约。
//
// 三个 case：
//  (a) succeeded > 0 -> 调 sendLocalNotification，title/body/isPassive 形态正确
//  (b) succeeded == 0 -> 不调 sendLocalNotification（静默不发）
//  (c) requestNotificationPermission native 返回 false -> 不抛、返回 false
//
// Mock 方式：手写 `messenger.setMockMethodCallHandler(channel, ...)`（与
// `test/unit/bg_task_scheduler_test.dart` 同款，不跑 build_runner）。
// MethodChannel 走 name-based 路由，测试侧 const MethodChannel 同名即可拦截
// `LocalNotifier._channel` 的 invokeMethod。
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/notifications/local_notifier.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.img_syncer/notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    // LocalNotifier.sendSyncCompleteNotification 读取全局 l10n，需在调用前初始化。
    // 直接走 delegate.load 绕开 MaterialApp，免拉起完整 binding widget 树。
    // delegate.load 返回 Future<AppLocalizations>（非空），无需 null-assert。
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    messenger.setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('LocalNotifier', () {
    test(
        '(a) succeeded > 0 时调用 sendLocalNotification 且参数形态正确',
        () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        // native 端 sendLocalNotification 完成时回 true（AppDelegate.swift:50）
        if (call.method == 'sendLocalNotification') return true;
        return null;
      });

      await LocalNotifier.sendSyncCompleteNotification(succeeded: 5, failed: 0);

      final sendCalls = calls
          .where((c) => c.method == 'sendLocalNotification')
          .toList();
      expect(sendCalls.length, 1);

      final args = sendCalls.first.arguments as Map<Object?, Object?>;
      expect(args['title'], l10n.bgSyncSuccessNotificationTitle);
      expect(args['body'], l10n.bgSyncSuccessNotificationBody(5));
      expect(args['isPassive'], true);
    });

    test('(b) succeeded == 0 时不调用 sendLocalNotification', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        return null;
      });

      await LocalNotifier.sendSyncCompleteNotification(succeeded: 0, failed: 3);

      final sendCalls = calls
          .where((c) => c.method == 'sendLocalNotification')
          .toList();
      expect(sendCalls, isEmpty);
    });

    test('(c) requestNotificationPermission 返回 false 时不抛', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'requestAuthorization') return false;
        return null;
      });

      // 不应抛 PlatformException / MissingPluginException；正常返回 false。
      final granted = await LocalNotifier.requestNotificationPermission();
      expect(granted, isFalse);
    });
  });
}

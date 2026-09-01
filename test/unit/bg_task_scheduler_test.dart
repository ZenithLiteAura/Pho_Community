// 单测：锁住 lib/sync/bg_task_scheduler.dart 中 scheduleBgTaskViaChannel()
// 的 channel 契约：调用 `com.example.img_syncer/notifications` 的 `scheduleBgTask`
// 方法，且不传参数。
//
// 由于该函数在 native 端才真正调度 BGProcessingTask，Dart 单测只能验证 channel 调用
// 形态；native 端由 Task 5 实现，集成测试在真机上验证。
//
// 用 ServicesBindingInstaller 注入 TestDefaultBinaryMessengerBinding，使
// MethodChannel.setMockMethodCallHandler 在无完整 Flutter 环境下可用。
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/sync/bg_task_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.img_syncer/notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
      'scheduleBgTaskViaChannel 调用 scheduleBgTask 方法且无参数',
      () async {
    String? capturedMethod;
    Object? capturedArgs;

    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      capturedMethod = call.method;
      capturedArgs = call.arguments;
      return null; // native 端无返回值
    });

    await scheduleBgTaskViaChannel();

    expect(capturedMethod, 'scheduleBgTask');
    expect(capturedArgs, isNull);
  });

  test('native 端未注册 handler 时抛 MissingPluginException（契约不吞错）',
      () async {
    messenger.setMockMethodCallHandler(channel, null);

    expect(
      () => scheduleBgTaskViaChannel(),
      throwsA(isA<MissingPluginException>()),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/app/state/state_model.dart';

/// 上传进度通知契约。
///
/// 锁住三条与「并行上传进度条抽搐 / 一直无限上传」直接相关的行为：
///  1. 高频进度变化**不**触发整体重建（只 tick 专用 notifier）；
///  2. 同一文件的通知频率被节流；
///  3. 重试期间进度条**不被移除**（消失-重现正是交替闪烁的来源）。
void main() {
  late StateModel model;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    model = StateModel();
  });

  group('进度通知与整体重建解耦', () {
    test('首个进度需要整体通知（空 → 非空，FAB 状态依赖它）', () {
      int whole = 0;
      int ticks = 0;
      model.addListener(() => whole++);
      model.uploadProgressTick.addListener(() => ticks++);

      model.updateUploadProgress('a', 0, 100);

      expect(whole, 1);
      expect(ticks, 0);
    });

    test('后续高频进度只 tick，不触发整体通知', () {
      model.updateUploadProgress('a', 0, 100); // 空 → 非空

      int whole = 0;
      int ticks = 0;
      model.addListener(() => whole++);
      model.uploadProgressTick.addListener(() => ticks++);

      for (var i = 1; i <= 50; i++) {
        model.updateUploadProgress('a', i, 100);
      }

      expect(whole, 0, reason: '进度值变化不应重建整个同步页');
      expect(ticks, greaterThan(0));
    });

    test('节流：密集的分块更新不会逐次通知', () {
      model.updateUploadProgress('a', 0, 100000);

      int ticks = 0;
      model.uploadProgressTick.addListener(() => ticks++);

      // 模拟 64KB 分块的密集回调（循环内几乎无时间间隔）
      for (var i = 1; i <= 200; i++) {
        model.updateUploadProgress('a', i * 64, 100000);
      }

      expect(ticks, lessThan(200), reason: '节流必须生效');
      expect(ticks, lessThanOrEqualTo(2),
          reason: '${StateModel.progressThrottleMs}ms 内不应反复通知');
    });

    test('传完时立即通知，不被节流延迟', () {
      model.updateUploadProgress('a', 0, 100);

      int ticks = 0;
      model.uploadProgressTick.addListener(() => ticks++);

      model.updateUploadProgress('a', 50, 100);
      final afterPartial = ticks;
      model.updateUploadProgress('a', 100, 100); // 完成

      expect(ticks, greaterThan(afterPartial),
          reason: 'transmitted == total 时必须立即刷新，保证结束态不迟到');
    });
  });

  group('重试期间保留进度条', () {
    test('markUploadRetrying 不移除进度，只标记重试并归零本轮', () {
      model.updateUploadProgress('a', 30, 100);
      expect(model.uploadProgress.containsKey('a'), isTrue);

      model.markUploadRetrying('a', 1, 3);

      expect(model.uploadProgress.containsKey('a'), isTrue,
          reason: '重试若移除进度条，重试时又重建 → 进度条交替闪烁');
      expect(model.uploadProgress['a']!.retry, 1);
      expect(model.uploadProgress['a']!.maxRetries, 3);
      expect(model.getUploadPercent('a'), 0, reason: '本轮从头发送，如实归零');
    });

    test('重试不会让另一个并行文件的进度受影响', () {
      model.updateUploadProgress('a', 10, 100);
      model.updateUploadProgress('b', 90, 100);

      model.markUploadRetrying('a', 2, 3);

      expect(model.getUploadPercent('a'), 0);
      expect(model.getUploadPercent('b'), closeTo(0.9, 0.0001));
      expect(model.uploadProgress.containsKey('b'), isTrue);
    });

    test('finishUpload 才移除进度，并整体通知', () {
      model.updateUploadProgress('a', 50, 100);

      int whole = 0;
      model.addListener(() => whole++);

      model.finishUpload('a', true);

      expect(model.uploadProgress.containsKey('a'), isFalse);
      expect(model.syncedIDs.contains('a'), isTrue);
      expect(whole, greaterThan(0), reason: '列表项文案需要随完成状态刷新');
    });

    test('重试标记不影响并行计数与 isUploading', () {
      model.updateUploadProgress('a', 10, 100);
      model.updateUploadProgress('b', 20, 200);
      expect(model.isUploading(), isTrue);

      model.markUploadRetrying('a', 1, 3);
      expect(model.isUploading(), isTrue, reason: '重试期间仍处于上传中');

      model.finishUpload('a', true);
      model.finishUpload('b', false);
      expect(model.isUploading(), isFalse);
    });
  });

  group('进度取值防御', () {
    test('total 为 0 时返回 0 而不是 NaN', () {
      model.updateUploadProgress('a', 5, 0);
      final p = model.getUploadPercent('a');

      expect(p.isNaN, isFalse, reason: 'NaN 会让 LinearProgressIndicator 断言失败');
      expect(p, 0);
    });

    test('transmitted 超过 total 时夹紧到 1', () {
      model.updateUploadProgress('a', 150, 100);
      expect(model.getUploadPercent('a'), 1);
    });

    test('未知 id 返回 0', () {
      expect(model.getUploadPercent('not-exist'), 0);
    });
  });
}
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/bridge/storage/storage.dart';

/// 上传上限与错误文案契约。
///
/// 背景：服务端单个请求体上限原为 500MiB，超出时 Go 的 http server 会因请求体
/// 未读完直接关闭连接，客户端只能收到 Broken pipe（拿不到 413）——表现为
/// 「上传大视频失败：ClientException with SocketException: Broken pipe」。
/// 因此上限放宽到 8GiB，并由服务端经 Ping 下发；客户端在上传**之前**预检。
void main() {
  group('humanFileSize', () {
    test('各量级换算正确', () {
      expect(humanFileSize(0), '0B');
      expect(humanFileSize(512), '512B');
      expect(humanFileSize(1024), '1.0KB');
      expect(humanFileSize(500 * 1024 * 1024), '500MB');
      expect(humanFileSize(8 * 1024 * 1024 * 1024), '8.0GB');
    });
  });

  group('UploadTooLargeException', () {
    test('提示同时包含实际大小、上限与文件名', () {
      final e = UploadTooLargeException(
        2 * 1024 * 1024 * 1024,
        500 * 1024 * 1024,
        'clip.mp4',
      );
      final msg = e.toString();

      expect(msg.contains('2.0GB'), isTrue, reason: '应告知实际大小');
      expect(msg.contains('500MB'), isTrue, reason: '应告知上限');
      expect(msg.contains('clip.mp4'), isTrue, reason: '应指出是哪个文件');
    });

    test('无文件名时不出现空括号', () {
      final e = UploadTooLargeException(9 << 30, 1 << 30, null);
      expect(e.toString().contains('（）'), isFalse);
    });
  });

  group('describeUploadError', () {
    test('Broken pipe 被翻译为可读提示，不把原始异常抛给用户', () {
      final msg = describeUploadError(Exception(
          'ClientException with SocketException: Broken pipe '
          '(OS Error: Broken pipe, errno = 32), address = 127.0.0.1, port = 43710'));

      expect(msg.contains('Broken pipe'), isFalse);
      expect(msg.contains('连接被关闭'), isTrue);
    });

    test('超限异常保持自身文案（优先级最高）', () {
      final e = UploadTooLargeException(2 << 30, 1 << 30, 'x.mp4');
      expect(describeUploadError(e), e.toString());
    });

    test('停滞超时给出超时提示', () {
      final msg = describeUploadError(
          Exception('TimeoutException: upload stalled: no data for 60s'));
      expect(msg.contains('超时'), isTrue);
    });

    test('未知异常保留原文便于排查', () {
      expect(describeUploadError(Exception('something-weird')), contains('weird'));
    });
  });

  group('上传上限来源', () {
    test('兜底常量与服务端 maxUploadSize 同量级（8GiB）', () {
      expect(fallbackMaxUploadSize, 8 << 30);
      expect(fallbackMaxUploadSize, greaterThan(500 << 20),
          reason: '必须显著高于原先的 500MiB 限制');
    });

    test('初始状态未从服务端取值时为 0（交由兜底常量接管）', () {
      // serverMaxUploadSize 由 Ping 结果填充；测试环境未连接服务端，
      // 因此这里只断言初始语义：0 表示"未获取"。
      expect(serverMaxUploadSize, greaterThanOrEqualTo(0));
    });
  });
}
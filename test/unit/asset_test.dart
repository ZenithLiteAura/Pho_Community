import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:http/http.dart' as http;

// video_player v2.11.1 使用 Pigeon / VideoPlayerPlatform.instance 模式，
// 不再使用原始 MethodChannel。通过替换 VideoPlayerPlatform.instance 为 Fake 实现来模拟。

class MockImgSyncerClient extends Mock implements ImgSyncerClient {}
class MockHttpClient extends Mock implements http.Client {}

/// Fake VideoPlayerPlatform，用于模拟远程视频初始化。
/// 可配置返回的 duration 或触发初始化错误。
class FakeVideoPlayerPlatformForTest extends VideoPlayerPlatform {
  int _nextPlayerId = 0;
  final Map<int, StreamController<VideoEvent>> _streams = {};
  Duration? _durationOverride;
  bool forceInitError = false;

  FakeVideoPlayerPlatformForTest({Duration? duration})
      : _durationOverride = duration;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final stream = StreamController<VideoEvent>();
    _streams[_nextPlayerId] = stream;

    if (forceInitError) {
      stream.addError(
          PlatformException(code: 'VideoError', message: 'test init error'));
    } else {
      stream.add(VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(1920, 1080),
        duration: _durationOverride ?? const Duration(seconds: 123),
      ));
    }
    return _nextPlayerId++;
  }

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _streams[playerId]!.stream;

  @override
  Widget buildView(int playerId) => Container();
}

RemoteImage _makeRemoteImage(String path) {
  return RemoteImage(
    MockImgSyncerClient(),
    path,
    httpClient: MockHttpClient(),
  );
}

/// 辅助函数：创建一个没有 local/remote 的 Asset 实例。
/// Asset 的正常创建需要 photo_manager 插件，这里直接设置字段绕过。
Asset _createAssetWithoutLocal() {
  return Asset();
}

void main() {
  group('Asset.getLocalFile', () {
    test('无 local 时返回 null 且不崩溃', () async {
      final asset = _createAssetWithoutLocal();
      final result = await asset.getLocalFile();
      expect(result, isNull);
    });

    test('localFile 已设置时直接返回缓存的 File', () async {
      final asset = _createAssetWithoutLocal();
      final tempFile = File('/tmp/test_dummy.txt');
      asset.localFile = tempFile;

      final result = await asset.getLocalFile();
      expect(result, tempFile);
    });

    test('localFile 从 null 场景正确返回 null', () async {
      final asset = _createAssetWithoutLocal();
      // 未设置 localFile，且 hasLocal 为 false
      final result = await asset.getLocalFile();
      expect(asset.localFile, isNull);
      expect(result, isNull);
    });

    test('getLocalFile 方法签名存在且可调用（验证 await 已添加）', () async {
      // 这个测试验证方法存在且是 Future 类型（编译时检查）
      final asset = _createAssetWithoutLocal();
      final future = asset.getLocalFile();
      expect(future, isA<Future<File?>>());
      final result = await future;
      expect(result, isNull);
    });
  });

  group('Asset.videoDuration', () {
    late FakeVideoPlayerPlatformForTest fakePlatform;

    setUp(() {
      fakePlatform = FakeVideoPlayerPlatformForTest();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    testWidgets('TestRemoteVideoDurationNonZero', (tester) async {
      httpBaseUrl = 'http://localhost:8000';
      final asset = Asset(remote: _makeRemoteImage('videos/test.mp4'));

      final duration = await asset.videoDuration();

      expect(duration, isNot(Duration.zero));
      expect(duration, const Duration(seconds: 123));
    });

    testWidgets('TestRemoteVideoDurationFallbackOnFail', (tester) async {
      httpBaseUrl = 'http://localhost:8000';
      fakePlatform.forceInitError = true;
      final asset = Asset(remote: _makeRemoteImage('videos/test.mp4'));

      final duration = await asset.videoDuration();

      expect(duration, Duration.zero);
    });

    testWidgets('TestRemoteVideoDurationCached', (tester) async {
      httpBaseUrl = 'http://localhost:8000';
      final asset = Asset(remote: _makeRemoteImage('videos/test.mp4'));

      final d1 = await asset.videoDuration();
      expect(d1, isNot(Duration.zero));

      // 修改 fake 的返回时长来验证缓存生效
      fakePlatform =
          FakeVideoPlayerPlatformForTest(duration: const Duration(seconds: 999));
      VideoPlayerPlatform.instance = fakePlatform;

      // 第二次调用应返回缓存值（与 d1 相同），而非新 fake 的 999
      final d2 = await asset.videoDuration();
      expect(d2, d1);
    });

    testWidgets('TestRemoteVideoDurationNonVideoReturnsZero', (tester) async {
      httpBaseUrl = 'http://localhost:8000';
      final asset = Asset(remote: _makeRemoteImage('photos/test.jpg'));

      final duration = await asset.videoDuration();

      expect(duration, Duration.zero);
    });
  });
}

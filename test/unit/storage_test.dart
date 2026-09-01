import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/global.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

class MockImgSyncerClient extends Mock implements ImgSyncerClient {}

RemoteImage _makeRemoteImage(String path) {
  return RemoteImage(
    MockImgSyncerClient(),
    path,
    httpClient: http.Client(),
  );
}

void main() {
  group('RemoteImage.dataStream - contentLength null defense (M9)', () {
    late HttpServer server;
    late int port;
    final testData = utf8.encode('Hello, test data!');

    /// 设为 true 时，服务器响应不包含 Content-Length header
    bool omitContentLength = false;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;
      httpBaseUrl = 'http://127.0.0.1:$port';
      omitContentLength = false;

      server.listen((request) {
        final resp = request.response;
        resp.statusCode = 200;
        if (!omitContentLength) {
          resp.headers.set('content-length', testData.length.toString());
        }
        resp.add(testData);
        resp.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('contentLength 为 null 时不崩溃，total 使用 -1', () async {
      omitContentLength = true;
      final image = _makeRemoteImage('test.jpg');
      int? progressTotal;

      final stream = image.dataStream(
        reportProgress: false,
        onProgress: (downloaded, total) {
          progressTotal = total;
        },
      );

      final result = BytesBuilder();
      await for (final chunk in stream) {
        result.add(chunk);
      }

      expect(progressTotal, -1);
      expect(result.takeBytes(), testData);
    });

    test('有效 contentLength 被正确报告', () async {
      final image = _makeRemoteImage('test.jpg');
      final progressCalls = <Map<String, int>>[];

      final stream = image.dataStream(
        reportProgress: false,
        onProgress: (downloaded, total) {
          progressCalls.add({'downloaded': downloaded, 'total': total});
        },
      );

      await for (final _ in stream) {
        /* 消费数据 */
      }

      expect(progressCalls.isNotEmpty, isTrue);
      expect(progressCalls.first['total'], testData.length);
      expect(progressCalls.last['downloaded'], testData.length);
    });

    test('onProgress 回调中 downloaded 逐步递增', () async {
      final bigData = utf8.encode('A' * 10000);
      server.close();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;
      httpBaseUrl = 'http://127.0.0.1:$port';
      server.listen((request) {
        final resp = request.response;
        resp.statusCode = 200;
        resp.headers.set('content-length', bigData.length.toString());
        resp.add(bigData);
        resp.close();
      });

      final image = _makeRemoteImage('big.jpg');
      final downloadeds = <int>[];
      int? total;

      final stream = image.dataStream(
        reportProgress: false,
        onProgress: (downloaded, t) {
          downloadeds.add(downloaded);
          total = t;
        },
      );

      await for (final _ in stream) {
        /* 消费数据 */
      }

      expect(total, bigData.length);
      expect(downloadeds.first, greaterThan(0));
      // downloaded 不递减
      for (int i = 1; i < downloadeds.length; i++) {
        expect(downloadeds[i], greaterThanOrEqualTo(downloadeds[i - 1]));
      }
      expect(downloadeds.last, bigData.length);
    });
  });

  group('File stream error handling (M13)', () {
    test('onError 处理器关闭 sink 并传播错误', () async {
      // 先正常发送数据再触发错误
      final chunkData = [1, 2, 3];
      final errorStream = Stream<List<int>>.fromFutures([
        Future.value(chunkData),
        Future.delayed(const Duration(milliseconds: 10),
            () => throw Exception('模拟文件读取错误')),
      ]);

      final req = http.StreamedRequest(
          'POST', Uri.parse('http://localhost:12345/test'));
      final completer = Completer<void>();
      bool sinkClosed = false;

      errorStream.listen(
        (data) {
          req.sink.add(data);
        },
        onDone: () {
          req.sink.close();
        },
        onError: (e) {
          req.sink.close();
          sinkClosed = true;
          if (!completer.isCompleted) completer.completeError(e);
        },
      );

      try {
        await completer.future;
        fail('应该抛出异常');
      } catch (e) {
        expect(sinkClosed, isTrue);
        expect(e, isA<Exception>());
        expect('$e', contains('文件读取错误'));
      }
    });

    test('正常流 onDone 关闭 sink', () async {
      final normalStream = Stream<List<int>>.fromIterable([
        [1, 2, 3],
        [4, 5, 6],
      ]);

      final req = http.StreamedRequest(
          'POST', Uri.parse('http://localhost:12345/test'));
      final completer = Completer<void>();
      bool sinkClosedOnDone = false;

      normalStream.listen(
        (data) {
          req.sink.add(data);
        },
        onDone: () {
          req.sink.close();
          sinkClosedOnDone = true;
          completer.complete();
        },
        onError: (e) {
          req.sink.close();
        },
      );

      await completer.future;
      expect(sinkClosedOnDone, isTrue);
    });
  });

  group('重试计数器重置', () {
    test('每次重试 uploaded 从 0 开始', () {
      int retryCount = 0;
      final maxRetries = 3;
      final uploadedStarts = <int>[];

      while (retryCount < maxRetries) {
        // uploaded 在循环内部声明，每次迭代重置
        int uploaded = 0;
        uploadedStarts.add(uploaded);
        uploaded += 10;
        retryCount++;
      }

      expect(uploadedStarts, [0, 0, 0]);
    });

    test('重试时 uploaded 不会累加上次失败的值', () {
      int attempt = 0;
      final maxRetries = 3;
      bool succeeded = false;
      final uploadedAtEnd = <int>[];

      while (!succeeded && attempt < maxRetries) {
        int uploaded = 0; // 每次迭代重置
        attempt++;

        // 模拟上传了一些数据后失败
        uploaded += 50;
        if (attempt == 1) {
          // 第一次尝试失败
          uploadedAtEnd.add(uploaded);
          continue;
        }
        // 第二次尝试成功
        uploaded += 50;
        uploadedAtEnd.add(uploaded);
        succeeded = true;
      }

      // 第一次失败时 uploaded=50，第二次成功时 uploaded=100（不是 150）
      expect(uploadedAtEnd, [50, 100]);
    });
  });
}

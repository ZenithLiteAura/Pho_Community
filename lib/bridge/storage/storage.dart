import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:grpc/grpc.dart';
import 'package:img_syncer/app/logger/logger.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:date_format/date_format.dart';
import 'package:img_syncer/app/state/state_model.dart';
import 'package:path/path.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:img_syncer/app/state/global.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:img_syncer/bridge/util.dart';
import 'package:img_syncer/core/hash_util.dart';
import 'package:img_syncer/bridge/storage/storage_interface.dart';

/// 将 EncryptionType 转为 HTTP 头字符串
String encryptionTypeName(EncryptionType type) {
  switch (type) {
    case EncryptionType.none:
      return 'None';
    case EncryptionType.aesCfb:
      return 'AES_128_CFB';
    case EncryptionType.aesGcm:
      return 'AES_256_GCM';
  }
}

RemoteStorage storage = RemoteStorage("127.0.0.1", 10000);

/// 测试注入用的 override，非 null 时替换 storage 全局变量
RemoteStorageClient? _storageOverride;
RemoteStorageClient get storageClient => _storageOverride ?? storage;
void setStorageForTest(RemoteStorageClient v) => _storageOverride = v;

/// 上传停滞看门狗。
///
/// 上传请求原先**没有任何超时**：NAS 慢或连接半开时 `await send()` 会永久挂起，
/// 同时占住并行上传信号量，表现为「进度条卡住、一直上传不完」。
/// 本看门狗在**连续 [_stallTimeout] 没有任何字节写出**时主动让请求失败，
/// 从而走既有重试路径。它检测的是「完全没有数据流动」而非「慢」，
/// 因此正常的大文件慢速上传不会被误杀。
class _StallWatchdog {
  static const Duration _stallTimeout = Duration(seconds: 60);

  Timer? _timer;
  bool _cancelled = false;
  http.StreamedRequest? _req;

  /// 绑定请求并开始计时（发起 send 之前调用）。
  void arm(http.StreamedRequest req) {
    _req = req;
    kick();
  }

  /// 每次成功写出数据后调用，重置计时。
  void kick() {
    if (_cancelled) return;
    _timer?.cancel();
    _timer = Timer(_stallTimeout, _trip);
  }

  void _trip() {
    if (_cancelled) return;
    final req = _req;
    if (req == null) return;
    try {
      // 让请求流携带错误结束 → send() 抛错 → 走重试，而不是永久挂起
      req.sink.addError(TimeoutException(
          'upload stalled: no data for ${_stallTimeout.inSeconds}s'));
    } catch (_) {
      // sink 已关闭：忽略
    }
  }

  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    _timer = null;
  }
}

/// 文件超过服务端单请求上传上限。
///
/// 单独定义类型而非直接抛 SocketException：超限是**不可恢复**错误，
/// 且必须在上传**之前**拦住 —— 服务端读到上限会直接关闭连接，
/// 客户端只能收到 Broken pipe，拿不到 413。
class UploadTooLargeException implements Exception {
  UploadTooLargeException(this.bytes, this.limit, this.name);

  final int bytes;
  final int limit;
  final String? name;

  @override
  String toString() {
    final label = name == null ? '' : '（$name）';
    return '文件 ${humanFileSize(bytes)} 超过服务端单次上传上限 '
        '${humanFileSize(limit)}$label，请压缩或分段后再试';
  }
}

/// 字节数转可读尺寸（B/KB/MB/GB/TB）。
String humanFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = (value >= 100 || unit == 0) ? 0 : 1;
  return '${value.toStringAsFixed(digits)}${units[unit]}';
}

/// 把上传过程中的底层异常翻译成用户可读的一句话。
///
/// 原始异常仍会写入 logger，这里只负责「看得懂」。
String describeUploadError(Object e) {
  if (e is UploadTooLargeException) return e.toString();
  final raw = e.toString();
  if (raw.contains('Broken pipe') || raw.contains('Connection closed')) {
    return '上传中断：与内置服务的连接被关闭。'
        '常见原因是文件超过服务端上限，或网络存储中途断开';
  }
  if (raw.contains('Connection reset')) {
    return '上传中断：连接被重置，请检查网络存储是否稳定';
  }
  if (raw.contains('SocketException')) {
    return '上传中断：网络连接异常';
  }
  if (raw.contains('TimeoutException') || raw.contains('stalled')) {
    return '上传超时：长时间没有数据传输，已中断';
  }
  return raw;
}

class RemoteStorage implements RemoteStorageClient {
  int bufferSize = 1024 * 1024;
  /// 共享 HTTP 客户端，复用连接减少 TCP 握手开销
  http.Client httpClient = http.Client();
  ImgSyncerClient cli = ImgSyncerClient(ClientChannel(
    "127.0.0.1",
    port: 50051,
    options: const ChannelOptions(
      credentials: ChannelCredentials.insecure(),
      keepAlive: ClientKeepAliveOptions(
        pingInterval: Duration(seconds: 20),
        permitWithoutCalls: true,
      ),
    ),
  ));
  RemoteStorage(String addr, int port) {
    final channel = ClientChannel(
      addr,
      port: port,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
      ),
    );
    cli = ImgSyncerClient(channel);
  }

  Future<void> uploadXFile(XFile file) async {
    await checkServer();
    final name = basename(file.path);
    final date = await file.lastModified();
    final dateStr =
        formatDate(date, [yyyy, ':', mm, ':', dd, ' ', HH, ':', nn, ':', ss]);
    var thumbnailSize = 200;
    if (isVideoByPath(file.path)) {
      thumbnailSize = 800;
    }
    var thumbnailData = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: thumbnailSize,
      minHeight: thumbnailSize,
      quality: 90,
    );
    int uploaded = 0;
    final imgLen = await file.length();
    // final thumbLen = thumbnailData!.length;
    final totalLen = imgLen;
    var req = http.StreamedRequest("POST", Uri.parse("$httpBaseUrl/$name"));
    req.headers['Image-Date'] = dateStr;
    req.contentLength = imgLen;
    file.openRead().listen((chunk) {
      uploaded += chunk.length;
      req.sink.add(chunk);
    }, onDone: () {
      req.sink.close();
    }, onError: (e) {
      req.sink.close();
      throw Exception("file read error: $e");
    });
    final response = await req.send();
    if (response.statusCode != 200) {
      throw Exception("upload failed: ${response.statusCode}");
    }
    final thumbRsp = await http.post(
      Uri.parse("$httpBaseUrl/thumbnail/$name"),
      body: thumbnailData,
      headers: {
        'Image-Date': dateStr,
      },
    );
    if (thumbRsp.statusCode != 200) {
      throw Exception("upload thumbnail failed: ${thumbRsp.statusCode}");
    }
  }

  Future<void> uploadAssetEntity(AssetEntity asset) async {
    await checkServer();
    // v2.2 优化：预热阶段 IO 并发。
    // titleAsync / thumbnailDataWithSize 不依赖 file.path，可与 originFile 并发执行。
    // 三者并行能省一个 IO 周期（~10-30% 加速，取决于磁盘速度）。
    String? name = asset.title;
    final thumbFuture = asset.thumbnailDataWithSize(
      asset.type == AssetType.video
          ? const ThumbnailSize.square(800)
          : const ThumbnailSize.square(200),
      quality: 90,
    );
    final titleFuture = name == null ? asset.titleAsync : null;
    final file = await asset.originFile;
    if (file == null) {
      throw Exception("asset file is null");
    }
    name ??= titleFuture != null ? await titleFuture : null;
    // 三重去重标记：内容哈希 / 服务器存储名 / 本地路径。
    // 任一命中即视为已上传，直接标记为已同步并跳过网络上传。
    // v2.2 优化：hash 与 thumbnail 并发计算。
    final hashFuture = FileHash.ofFile(file);
    final thumbnailData = await thumbFuture;
    final hash = await hashFuture;
    final path = file.path;
    if ((hash != null && stateModel.isHashUploaded(hash)) ||
        stateModel.isPathUploaded(path) ||
        (name != null && stateModel.isNameUploaded(name))) {
      stateModel.finishUpload(asset.id, true);
      if (hash != null) await stateModel.recordUploadedHash(hash);
      await stateModel.recordUploadedPath(path);
      if (name != null) await stateModel.recordUploadedName(name);
      return;
    }
    // print("upload $name");
    var date = asset.createDateTime;
    if (date.isBefore(DateTime(1990, 1, 1))) {
      date = asset.modifiedDateTime;
    }
    final dateStr =
        formatDate(date, [yyyy, ':', mm, ':', dd, ' ', HH, ':', nn, ':', ss]);
    // v2.2：thumbnailData 已在前面并发预热，这里仅做 null 检查。
    // 缩略图生成失败不阻断主文件上传：记录日志、跳过缩略图上传，
    // 避免「永远生成不出缩略图 → 永远上传失败 → 无限重复上传」。
    if (thumbnailData == null) {
      logger.addWarning(
          "upload $name: thumbnail is null, skip thumbnail (original still uploads)");
    }
    File? liveVideoFile;
    final imgLen = await file.length();
    // 上传前预检：超过服务端上限就直接失败，不发起请求。
    // 放在重试循环之外 —— 超限是不可恢复错误，重试只会把同一份大文件再传一遍。
    _assertUploadSize(imgLen, name);
    final thumbLen = thumbnailData?.length ?? 0;
    int totalLen = imgLen + thumbLen;
    if (asset.isLivePhoto) {
      liveVideoFile = await asset.originFileWithSubtype;
      if (liveVideoFile != null) {
        final liveLen = await liveVideoFile.length();
        _assertUploadSize(liveLen, name);
        totalLen += liveLen;
      }
    }
    stateModel.updateUploadProgress(asset.id, 1, totalLen);
    logger.addDebug('upload start: $name (${humanFileSize(imgLen)})');
    int maxRetries = 3;
    int retryCount = 0;
    bool succeeded = false;
    while (!succeeded) {
      int uploaded = 0;
      try {
        // upload thumbnail（可选）
        if (thumbnailData != null) {
          final thumbRsp = await http.post(
            Uri.parse("$httpBaseUrl/thumbnail/$name"),
            body: thumbnailData,
            headers: {
              'Image-Date': dateStr,
              'Image-Is-Live-Photo': asset.isLivePhoto ? "true" : "false",
              'Image-Encrypt-Type': settingModel.enableEncrypt
                  ? encryptionTypeName(settingModel.encryptionType)
                  : "None",
              'Image-Encrypt-Password': settingModel.enableEncrypt
                  ? settingModel.encryptionPassword
                : "",
          },
        );
        stateModel.updateUploadProgress(
            asset.id, uploaded + thumbLen, totalLen);
        if (thumbRsp.statusCode != 200) {
          // 缩略图上传失败不阻断主文件上传（避免无限重试同一文件）
          logger.addWarning(
              "upload $name thumbnail failed (skip, original still uploads): ${thumbRsp.statusCode} ${thumbRsp.body}");
        }
      }
        // upload origin image
        var req = http.StreamedRequest("POST", Uri.parse("$httpBaseUrl/$name"));
        req.headers['Image-Date'] = dateStr;
        req.headers['Image-Is-Live-Photo'] =
            asset.isLivePhoto ? "true" : "false";
        if (settingModel.enableEncrypt) {
          req.headers['Image-Encrypt-Type'] =
              encryptionTypeName(settingModel.encryptionType);
          req.headers['Image-Encrypt-Password'] =
              settingModel.encryptionPassword;
        }
        final imgLength = await file.length();
        req.contentLength = imgLength;
        final stall = _StallWatchdog();
        file.openRead().listen((chunk) {
          uploaded += chunk.length;
          stateModel.updateUploadProgress(asset.id, uploaded, totalLen);
          stall.kick();
          req.sink.add(chunk);
        }, onDone: () {
          stall.cancel();
          req.sink.close();
        }, onError: (e) {
          stall.cancel();
          req.sink.close();
          throw Exception("file read error: $e");
        });
        stall.arm(req);
        final response = await _sendUpload(req, imgLength);
        stall.cancel();
        if (response.statusCode != 200) {
          final body = await response.stream.bytesToString();
          throw Exception("upload failed: [${response.statusCode}] $body");
        }
        // upload Live Photo video
        if (asset.isLivePhoto && liveVideoFile != null) {
          final videoName = await asset.titleAsyncWithSubtype;
          var req = http.StreamedRequest(
              "POST", Uri.parse("$httpBaseUrl/live/$videoName"));
          req.headers['Image-Date'] = dateStr;
          req.headers['Image-Is-Live-Photo'] =
              asset.isLivePhoto ? "true" : "false";
          if (settingModel.enableEncrypt) {
            req.headers['Image-Encrypt-Type'] =
                encryptionTypeName(settingModel.encryptionType);
            req.headers['Image-Encrypt-Password'] =
                settingModel.encryptionPassword;
          }
          final videoLength = await liveVideoFile.length();
          req.contentLength = videoLength;
          final videoStall = _StallWatchdog();
          liveVideoFile.openRead().listen((chunk) {
            uploaded += chunk.length;
            stateModel.updateUploadProgress(asset.id, uploaded, totalLen);
            videoStall.kick();
            req.sink.add(chunk);
          }, onDone: () {
            videoStall.cancel();
            req.sink.close();
          }, onError: (e) {
            videoStall.cancel();
            req.sink.close();
            throw Exception("file read error: $e");
          });
          videoStall.arm(req);
          final response = await _sendUpload(req, videoLength);
          videoStall.cancel();
          if (response.statusCode != 200) {
            final body = await response.stream.bytesToString();
            throw Exception("upload failed: [${response.statusCode}] $body");
          }
        }
        stateModel.finishUpload(asset.id, true);
        logger.addDebug('upload done: $name (${humanFileSize(imgLen)})');
        // 上传成功：记录三重去重标记（哈希 / 名称 / 路径），下次自动排除
        if (hash != null) {
          await stateModel.recordUploadedHash(hash);
        }
        await stateModel.recordUploadedPath(path);
        if (name != null) {
          await stateModel.recordUploadedName(name);
        }
        succeeded = true;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          // 仅在「最终失败」时移除进度条。原先每次失败都 finishUpload，
          // 会让进度条消失、重试时又重建，并行上传时表现为两条进度条交替闪烁。
          stateModel.finishUpload(asset.id, false);
          logger.addError("upload $name failed: $e");
          // 抛原始异常会让 UI 显示一长串 ClientException/SocketException，
          // 这里归一成可读提示；原始异常已写入 logger 便于排查。
          throw Exception(describeUploadError(e));
        }
        // 重试：保留进度条并标记重试次数，UI 显示「重试中 n/max」。
        stateModel.markUploadRetrying(asset.id, retryCount, maxRetries);
        logger.addWarning("upload $name retry $retryCount/$maxRetries: $e");
      } finally {
        if (Platform.isIOS) {
          Future.delayed(const Duration(milliseconds: 200), () {
            try {
              file.deleteSync();
              liveVideoFile?.deleteSync();
            } catch (e) {
              logger.addLog("delete file failed: $e");
            }
          });
        }
      }
    }
  }

  /// 单请求上传上限：优先用服务端经 Ping 下发的值，未获取到则用兜底常量。
  int get _maxUploadSize =>
      serverMaxUploadSize > 0 ? serverMaxUploadSize : fallbackMaxUploadSize;

  /// 上传前预检文件大小；超限直接抛 [UploadTooLargeException]，不发起上传。
  void _assertUploadSize(int bytes, String? name) {
    final limit = _maxUploadSize;
    if (bytes <= limit) return;
    throw UploadTooLargeException(bytes, limit, name);
  }

  /// 发送上传请求。
  ///
  /// 复用 [httpClient] 连接池（原先用 `req.send()` 每次新建连接，并行上传大文件
  /// 时损耗明显），并对整体耗时设一个**宽松兜底超时**：按「至少 64KB/s」的保守
  /// 速率估算，避免误杀正常的大文件上传。真正的卡死防线是 [_StallWatchdog]。
  Future<http.StreamedResponse> _sendUpload(
      http.StreamedRequest req, int contentLength) {
    final estimatedTimeout =
        Duration(seconds: (contentLength / (64 * 1024)).ceil() + 300);
    return httpClient.send(req).timeout(estimatedTimeout);
  }

  // @protected
  // Stream<UploadRequest> uploadStream(Stream<List<int>> dataReader,
  //     Stream<Uint8List> thumbnailReader, String name, date) async* {
  //   yield UploadRequest(name: name, date: date);
  //   await for (var data in dataReader) {
  //     yield UploadRequest(data: data);
  //   }
  //   await for (var data in thumbnailReader) {
  //     yield UploadRequest(thumbnailData: data);
  //   }
  // }

  Future<List<RemoteImage>> listImages(
      String date, int offset, maxReturn) async {
    final rsp = await cli
        .listByDate(
          ListByDateRequest(
            date: date,
            offset: offset,
            maxReturn: maxReturn,
          ),
        )
        .timeout(const Duration(seconds: 60));
    if (!rsp.success) {
      throw Exception("list images failed: ${rsp.message}");
    }
    return rsp.infos
        .map((e) => RemoteImage(cli, e.path.replaceAll('\\', '/'),
            size: e.size.toInt(),
            isLivePhoto: e.isLivePhoto,
            httpClient: httpClient))
        .toList();
  }
}

class RemoteImage {
  ImgSyncerClient cli;
  String path;
  int? size;
  Uint8List? data;
  Uint8List? thumbnailData;
  bool isLivePhoto = false;
  /// 共享 HTTP 客户端，复用连接减少 TCP 握手开销
  late http.Client httpClient;

  RemoteImage(
    this.cli,
    this.path, {
    this.data,
    this.thumbnailData,
    this.size,
    this.isLivePhoto = false,
    required this.httpClient,
  });

  bool isVideo() {
    return isVideoByPath(path);
  }

  Stream<Uint8List> thumbnailStream() async* {
    await checkServer();
    var urlPath = path;
    if (urlPath[0] == '/') {
      urlPath = urlPath.substring(1);
    }
    final url = '$httpBaseUrl/thumbnail/$urlPath';
    final request = http.Request('GET', Uri.parse(url));
    if (settingModel.enableEncrypt) {
      request.headers['Image-Encrypt-Type'] =
          encryptionTypeName(settingModel.encryptionType);
      request.headers['Image-Encrypt-Password'] =
          settingModel.encryptionPassword;
    }
    final response = await httpClient.send(request);
    if (response.statusCode != 200) {
      final errMsg = await response.stream.bytesToString();
      throw Exception(
          "get [$urlPath] thumbnail failed: [${response.reasonPhrase}] $errMsg");
    }
    await for (var data in response.stream) {
      yield data as Uint8List;
    }
  }

  Future<Uint8List> thumbnail() async {
    if (thumbnailData != null) {
      return thumbnailData!;
    }
    int maxRetries = 3;
    int retryCount = 0;
    bool succeeded = false;
    while (retryCount < maxRetries && !succeeded) {
      try {
        var currentData = BytesBuilder();
        var dataStream = thumbnailStream();
        await for (var d in dataStream) {
          currentData.add(d);
        }
        thumbnailData = currentData.takeBytes();
        succeeded = true;
      } catch (e) {
        logger.addLog("get $path thumbnail failed: $e");
        retryCount++;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (!succeeded) {
      final data = await rootBundle.load("assets/images/broken.png");
      thumbnailData = data.buffer.asUint8List();
    }
    return thumbnailData!;
  }

  Stream<Uint8List> dataStream({
    bool reportProgress = true,
    void Function(int downloaded, int total)? onProgress,
  }) async* {
    await checkServer();
    if (path[0] == '/') {
      path = path.substring(1);
    }
    final url = '$httpBaseUrl/$path';
    final request = http.Request('GET', Uri.parse(url));
    if (settingModel.enableEncrypt) {
      request.headers['Image-Encrypt-Type'] =
          encryptionTypeName(settingModel.encryptionType);
      request.headers['Image-Encrypt-Password'] =
          settingModel.encryptionPassword;
    }
    final response = await httpClient.send(request);
    if (response.statusCode != 200) {
      throw Exception("get image failed: ${response.statusCode}");
    }
    final total = response.contentLength ?? -1;
    if (reportProgress) {
      stateModel.updateDownloadProgress(basename(path), 1, total);
    }
    if (onProgress != null) {
      onProgress(1, total);
    }
    int downloaded = 0;
    await for (var data in response.stream) {
      downloaded += data.length;
      if (reportProgress) {
        stateModel.updateDownloadProgress(basename(path), downloaded, total);
      }
      if (onProgress != null) {
        onProgress(downloaded, total);
      }
      yield data as Uint8List;
    }
    if (reportProgress) {
      stateModel.finishDownload(basename(path), true);
    }
    if (onProgress != null) {
      onProgress(downloaded, total);
    }
  }

  Future<Uint8List> imageData({
    bool reportProgress = true,
    void Function(int downloaded, int total)? onProgress,
  }) async {
    if (data != null) {
      return data!;
    }
    var currentData = BytesBuilder();
    var stream = dataStream(
      reportProgress: reportProgress,
      onProgress: onProgress,
    );
    await for (var d in stream) {
      currentData.add(d);
    }
    data = currentData.takeBytes();
    return data!;
  }
}

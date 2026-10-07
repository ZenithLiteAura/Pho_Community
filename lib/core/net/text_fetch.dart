import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 以 GET 拉取一段文本（用于读取仓库里的静态 JSON 资源，如公告）。
///
/// 约定：
/// - 失败 / 超时 / 非 200 一律返回 null，绝不抛异常，调用方按「静默跳过」处理；
/// - Web 平台没有 `dart:io`，直接返回 null（本应用发行目标是移动端与桌面端）；
/// - 显式带 User-Agent：部分 CDN 对空 UA 会返回 403。
Future<String?> fetchText(
  String url, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (kIsWeb) return null;

  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
    request.headers.set(HttpHeaders.userAgentHeader, 'Pho-Community-App');
    request.headers
        .set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');

    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }
    return await response.transform(utf8.decoder).join().timeout(timeout);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

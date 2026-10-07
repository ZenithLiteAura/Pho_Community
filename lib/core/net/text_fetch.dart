import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 一次静态资源拉取的结果（含状态码与耗时，供诊断展示）。
@immutable
class HttpTextResult {
  const HttpTextResult({
    this.status,
    this.body,
    this.error,
    required this.elapsed,
  });

  /// HTTP 状态码；网络层失败时为 null。
  final int? status;

  /// 响应体；失败时为 null。
  final String? body;

  /// 失败原因（异常简要信息）。
  final String? error;

  final Duration elapsed;

  bool get ok => status == HttpStatus.ok && body != null;
}

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
  final result = await fetchTextDetailed(url, timeout: timeout);
  return result.body;
}

/// 同 [fetchText]，但保留状态码、耗时与错误信息，便于开发者选项里逐个源诊断。
Future<HttpTextResult> fetchTextDetailed(
  String url, {
  Duration timeout = const Duration(seconds: 8),
  String userAgent = 'Pho-Community-App',
  Map<String, String>? headers,
}) async {
  final started = DateTime.now();
  Duration elapsed() => DateTime.now().difference(started);

  if (kIsWeb) {
    return HttpTextResult(elapsed: elapsed(), error: 'web platform unsupported');
  }

  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    request.headers
        .set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
    headers?.forEach((k, v) => request.headers.set(k, v));

    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      return HttpTextResult(
        status: response.statusCode,
        elapsed: elapsed(),
        error: 'HTTP ${response.statusCode}',
      );
    }
    return HttpTextResult(status: response.statusCode, body: body, elapsed: elapsed());
  } catch (e) {
    return HttpTextResult(elapsed: elapsed(), error: e.toString());
  } finally {
    client.close(force: true);
  }
}

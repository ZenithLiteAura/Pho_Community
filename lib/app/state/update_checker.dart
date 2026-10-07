import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:img_syncer/app/state/community_info.dart';

/// GitHub Releases API：本仓库最新正式版本。
const String latestReleaseApiUrl =
    'https://api.github.com/repos/ZenithLiteAura/Pho_Community/releases/latest';

/// GitHub Releases 页面（下载兜底入口）。
const String releasesPageUrl =
    'https://github.com/ZenithLiteAura/Pho_Community/releases';

/// 「启动时自动检查更新」的持久化 key。
///
/// `false`（默认）表示启动后自动在 GitHub 上检查一次；
/// 用户可在「设置 → 关于 → 高级设置」里改为 `true` 关闭。
const String autoUpdateCheckPrefKey = 'auto_update_check_disabled';

/// 一条 GitHub Release 的摘要。
class AppRelease {
  const AppRelease({
    required this.tag,
    required this.name,
    required this.htmlUrl,
    required this.body,
  });

  /// 原始 tag，例如 `v3.5-community`。
  final String tag;

  /// Release 标题。
  final String name;

  /// Release 页面地址。
  final String htmlUrl;

  /// Release 说明（Markdown 原文）。
  final String body;

  /// 从 tag 中解析出的版本号（`v3.5-community` -> `3.5`）；解析失败返回 null。
  String? get version => extractVersion(tag);
}

/// 更新检查结果。
class UpdateCheckResult {
  const UpdateCheckResult({required this.ok, this.release, this.error});

  /// 网络请求是否成功。为 false 时 [release] 必为 null。
  final bool ok;

  /// 存在比当前版本更新的发行版时为其摘要，否则为 null。
  final AppRelease? release;

  /// 失败原因（仅用于日志/调试，不直接展示给用户）。
  final String? error;

  bool get hasUpdate => release != null;
}

/// 提取字符串中第一段 `数字(.数字)*` 形式的版本号。
///
/// 允许 tag 带前缀/后缀（`v3.5`、`3.5-community`、`release-3.5.1`）。
String? extractVersion(String raw) {
  final match = RegExp(r'\d+(?:\.\d+)*').firstMatch(raw);
  return match?.group(0);
}

/// [candidate] 是否比 [current] 更新。
///
/// 逐段按整数比较，段数不同时缺省段视为 0（`3.4` 与 `3.4.0` 相等）。
/// 任一侧无法解析时返回 false —— 宁可漏报也不误报。
bool isNewerVersion(String candidate, String current) {
  final a = extractVersion(candidate);
  final b = extractVersion(current);
  if (a == null || b == null) return false;
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va > vb;
  }
  return false;
}

/// 查询 GitHub 上是否存在比 [communityVersion] 更新的正式发行版本。
///
/// - 未认证调用受 GitHub 速率限制（60 次/小时/IP）；失败时返回 `ok: false`，
///   由调用方决定静默忽略还是提示用户；
/// - Web 平台没有 `dart:io`，直接返回失败（本应用的发行目标是移动端/桌面端）。
Future<UpdateCheckResult> checkForUpdate({
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (kIsWeb) {
    return const UpdateCheckResult(ok: false, error: 'web platform unsupported');
  }

  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request =
        await client.getUrl(Uri.parse(latestReleaseApiUrl)).timeout(timeout);
    // GitHub API 强制要求 User-Agent，缺失会直接 403。
    request.headers
        .set(HttpHeaders.userAgentHeader, 'Pho-Community-Update-Checker');
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');

    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return UpdateCheckResult(ok: false, error: 'HTTP ${response.statusCode}');
    }

    final raw = await response.transform(utf8.decoder).join().timeout(timeout);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const UpdateCheckResult(ok: false, error: 'malformed payload');
    }

    final tag = (decoded['tag_name'] ?? '').toString();
    if (tag.isEmpty) {
      return const UpdateCheckResult(ok: false, error: 'missing tag_name');
    }
    if (!isNewerVersion(tag, communityVersion)) {
      return const UpdateCheckResult(ok: true);
    }

    return UpdateCheckResult(
      ok: true,
      release: AppRelease(
        tag: tag,
        name: (decoded['name'] ?? tag).toString(),
        htmlUrl: (decoded['html_url'] ?? releasesPageUrl).toString(),
        body: (decoded['body'] ?? '').toString(),
      ),
    );
  } catch (e) {
    return UpdateCheckResult(ok: false, error: e.toString());
  } finally {
    client.close(force: true);
  }
}

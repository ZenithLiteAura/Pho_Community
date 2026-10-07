import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/core/net/text_fetch.dart';

/// 公告所在的仓库坐标（推送公告用）。
const String phoRepoOwner = 'ZenithLiteAura';
const String phoRepoName = 'Pho_Community';
const String phoRepoBranch = 'main';
const String phoAnnouncementPath = 'docs/announcement.json';

/// GitHub Token 的本地存储 key。
///
/// 只存在开发者自己这台设备上（SharedPreferences），既不进源码也不进仓库。
const String devGithubTokenPrefKey = 'dev_github_token';

/// 单个公告源的探测结果。
@immutable
class AnnouncementSourceProbe {
  const AnnouncementSourceProbe({
    required this.url,
    this.status,
    this.elapsedMs = 0,
    this.jsonOk = false,
    this.announcement,
    this.error,
    this.snippet,
  });

  final String url;
  final int? status;
  final int elapsedMs;

  /// 返回体是否为可解析的 JSON 对象（即这条源「可用」）。
  final bool jsonOk;

  /// 解析出的公告；`enabled` 非 true 时为 null。
  final Announcement? announcement;

  final String? error;

  /// 返回体前若干字符，便于肉眼确认拿到的是哪一版。
  final String? snippet;

  bool get usable => jsonOk;

  /// 这条源会不会让客户端弹公告。
  bool get wouldNotify => announcement != null;
}

/// 依次探测全部公告源（并发请求，但分别记录状态码与耗时）。
Future<List<AnnouncementSourceProbe>> probeAnnouncementSources({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final futures = announcementSources
      .map((url) => _probeOne(url, timeout))
      .toList(growable: false);
  return Future.wait(futures);
}

Future<AnnouncementSourceProbe> _probeOne(String url, Duration timeout) async {
  final r = await fetchTextDetailed(url, timeout: timeout);
  final body = r.body;
  if (body == null) {
    return AnnouncementSourceProbe(
      url: url,
      status: r.status,
      elapsedMs: r.elapsed.inMilliseconds,
      error: r.error ?? 'no body',
    );
  }
  final snippet = body.length > 120 ? '${body.substring(0, 120)}…' : body;
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    return AnnouncementSourceProbe(
      url: url,
      status: r.status,
      elapsedMs: r.elapsed.inMilliseconds,
      error: '不是合法 JSON',
      snippet: snippet,
    );
  }
  if (decoded is! Map) {
    return AnnouncementSourceProbe(
      url: url,
      status: r.status,
      elapsedMs: r.elapsed.inMilliseconds,
      error: 'JSON 顶层不是对象',
      snippet: snippet,
    );
  }
  return AnnouncementSourceProbe(
    url: url,
    status: r.status,
    elapsedMs: r.elapsed.inMilliseconds,
    jsonOk: true,
    announcement: Announcement.parse(body),
    snippet: snippet,
  );
}

/// 用表单内容拼出公告 JSON（`enabled` 固定为 true）。
String buildAnnouncementJson({
  required String id,
  required String level,
  required String titleZh,
  required String titleEn,
  required String bodyZh,
  required String bodyEn,
  String url = '',
  bool once = true,
}) {
  final map = <String, Object?>{
    'enabled': true,
    'id': id.trim(),
    'level': level,
    'title': {'zh': titleZh.trim(), 'en': titleEn.trim()},
    'body': {'zh': bodyZh.trim(), 'en': bodyEn.trim()},
    'url': url.trim(),
    'startAt': '',
    'endAt': '',
    'minVersion': '',
    'maxVersion': '',
    'once': once,
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// 公告 JSON 的**关闭**版本（用于下线公告）。
String buildDisabledAnnouncementJson({String id = 'disabled'}) {
  final map = <String, Object?>{
    'enabled': false,
    'id': id,
    'level': 'info',
    'title': {'zh': '', 'en': ''},
    'body': {'zh': '', 'en': ''},
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// 推送结果。
@immutable
class PublishResult {
  const PublishResult({required this.ok, required this.message, this.status});

  final bool ok;
  final String message;
  final int? status;
}

/// 把公告 JSON 提交到仓库的 `docs/announcement.json`（GitHub Contents API）。
///
/// 需要 PAT：内容推送走 REST，没有 Token 一律失败 —— 这也是开发者选项
/// 唯一真正需要权限的操作。
Future<PublishResult> publishAnnouncement({
  required String token,
  required String jsonText,
  String commitMessage = 'docs: 更新应用内公告',
}) async {
  if (token.trim().isEmpty) {
    return const PublishResult(ok: false, message: '缺少 GitHub Token');
  }
  try {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      return const PublishResult(ok: false, message: '公告必须是 JSON 对象');
    }
  } catch (e) {
    return PublishResult(ok: false, message: 'JSON 解析失败：$e');
  }

  final api =
      'https://api.github.com/repos/$phoRepoOwner/$phoRepoName/contents/$phoAnnouncementPath';
  try {
    final got = await _ghRequest('GET', '$api?ref=$phoRepoBranch', token: token);
    if (got.status != 200) {
      return PublishResult(
        ok: false,
        status: got.status,
        message: '读取远端文件失败（HTTP ${got.status}）：${_ghMessage(got.body)}',
      );
    }
    final sha = (jsonDecode(got.body) as Map)['sha']?.toString();

    final put = await _ghRequest(
      'PUT',
      api,
      token: token,
      jsonBody: <String, Object?>{
        'message': commitMessage,
        'content': base64Encode(utf8.encode(jsonText)),
        if (sha != null && sha.isNotEmpty) 'sha': sha,
        'branch': phoRepoBranch,
      },
    );
    if (put.status == 200 || put.status == 201) {
      final commitSha =
          ((jsonDecode(put.body) as Map)['commit'] as Map?)?['sha']?.toString() ?? '';
      final short = commitSha.length >= 7 ? commitSha.substring(0, 7) : commitSha;
      return PublishResult(
        ok: true,
        status: put.status,
        message: short.isEmpty ? '已提交' : '已提交 $short',
      );
    }
    return PublishResult(
      ok: false,
      status: put.status,
      message: '提交失败（HTTP ${put.status}）：${_ghMessage(put.body)}',
    );
  } catch (e) {
    return PublishResult(ok: false, message: '请求异常：$e');
  }
}

/// 一条公告历史（= 一次修改 docs/announcement.json 的提交）。
@immutable
class AnnouncementRevision {
  const AnnouncementRevision({
    required this.sha,
    required this.message,
    this.date,
    this.author,
  });

  final String sha;
  final String message;
  final String? date;
  final String? author;

  String get shortSha => sha.length >= 7 ? sha.substring(0, 7) : sha;
}

/// 历史列表结果。
@immutable
class HistoryResult {
  const HistoryResult({
    required this.ok,
    required this.revisions,
    required this.message,
  });

  final bool ok;
  final List<AnnouncementRevision> revisions;
  final String message;
}

/// 读取 `docs/announcement.json` 的提交历史（最近 [limit] 次）。
Future<HistoryResult> fetchAnnouncementHistory({
  required String token,
  int limit = 30,
}) async {
  if (token.trim().isEmpty) {
    return const HistoryResult(ok: false, revisions: [], message: '缺少 GitHub Token');
  }
  final url = 'https://api.github.com/repos/$phoRepoOwner/$phoRepoName/commits'
      '?path=$phoAnnouncementPath&per_page=$limit';
  try {
    final r = await _ghRequest('GET', url, token: token);
    if (r.status != 200) {
      return HistoryResult(
        ok: false,
        revisions: const [],
        message: '读取历史失败（HTTP ${r.status}）：${_ghMessage(r.body)}',
      );
    }
    final decoded = jsonDecode(r.body);
    if (decoded is! List) {
      return const HistoryResult(ok: false, revisions: [], message: '返回格式异常');
    }
    final revisions = <AnnouncementRevision>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final commit = item['commit'] is Map
          ? Map<String, dynamic>.from(item['commit'] as Map)
          : <String, dynamic>{};
      final author = commit['author'] is Map
          ? Map<String, dynamic>.from(commit['author'] as Map)
          : <String, dynamic>{};
      final sha = (item['sha'] ?? '').toString();
      if (sha.isEmpty) continue;
      revisions.add(AnnouncementRevision(
        sha: sha,
        message: (commit['message'] ?? '').toString().split('\n').first,
        date: author['date']?.toString(),
        author: author['name']?.toString(),
      ));
    }
    return HistoryResult(ok: true, revisions: revisions, message: '共 ${revisions.length} 条');
  } catch (e) {
    return HistoryResult(ok: false, revisions: const [], message: '请求异常：$e');
  }
}

/// 读取指定版本（默认当前分支）的公告 JSON 文本。
Future<String?> fetchAnnouncementContent({
  required String token,
  String? ref,
}) async {
  if (token.trim().isEmpty) return null;
  final target = (ref == null || ref.isEmpty) ? phoRepoBranch : ref;
  final url = 'https://api.github.com/repos/$phoRepoOwner/$phoRepoName/contents'
      '/$phoAnnouncementPath?ref=$target';
  try {
    final r = await _ghRequest('GET', url, token: token);
    if (r.status != 200) return null;
    final decoded = jsonDecode(r.body);
    if (decoded is! Map) return null;
    final content = (decoded['content'] ?? '').toString().replaceAll('\n', '');
    if (content.isEmpty) return null;
    return utf8.decode(base64Decode(content));
  } catch (_) {
    return null;
  }
}

/// 回滚：把某个历史版本的内容重新提交为最新（不是 git revert，公告只有一条主线）。
Future<PublishResult> restoreAnnouncementRevision({
  required String token,
  required String sha,
}) async {
  final text = await fetchAnnouncementContent(token: token, ref: sha);
  if (text == null) {
    return const PublishResult(ok: false, message: '读取该版本内容失败');
  }
  final short = sha.length >= 7 ? sha.substring(0, 7) : sha;
  return publishAnnouncement(
    token: token,
    jsonText: text,
    commitMessage: 'docs: 回滚公告到 $short',
  );
}

Future<String> readSeenAnnouncementIds() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(announcementSeenIdsKey) ?? '';
  } catch (_) {
    return '';
  }
}

/// 清空「已读公告」记录，方便反复测试同一则公告。
Future<void> clearSeenAnnouncementIds() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(announcementSeenIdsKey);
  } catch (_) {
    // 忽略
  }
}

Future<String> readDevGithubToken() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(devGithubTokenPrefKey) ?? '';
  } catch (_) {
    return '';
  }
}

Future<void> saveDevGithubToken(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (token.trim().isEmpty) {
      await prefs.remove(devGithubTokenPrefKey);
    } else {
      await prefs.setString(devGithubTokenPrefKey, token.trim());
    }
  } catch (_) {
    // 忽略
  }
}

/// 供开发者选项展示的诊断文本。
String buildDiagnosticsText({
  required List<AnnouncementSourceProbe> probes,
  required String seenIds,
  required bool startupNoticeDisabled,
  required bool updateCheckDisabled,
  required bool announcementCheckDisabled,
}) {
  final b = StringBuffer();
  b.writeln('$communityAppName $communityVersion');
  b.writeln('包名：com.ZenithLiteAura.app.pho.community');
  b.writeln('平台：${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  b.writeln('仓库：$phoRepoOwner/$phoRepoName@$phoRepoBranch');
  b.writeln('公告文件：$phoAnnouncementPath');
  b.writeln('');
  b.writeln('开关：关闭启动弹窗=$startupNoticeDisabled，'
      '关闭自动检查更新=$updateCheckDisabled，关闭公告检查=$announcementCheckDisabled');
  b.writeln('已读公告 id：${seenIds.isEmpty ? '（无）' : seenIds}');
  b.writeln('');
  for (final p in probes) {
    b.writeln('[${p.status ?? '-'}] ${p.elapsedMs}ms '
        '${p.usable ? (p.wouldNotify ? '会弹 id=${p.announcement!.id} level=${p.announcement!.level.name}' : '可用但 enabled!=true') : '不可用(${p.error})'}');
    b.writeln('    ${p.url}');
  }
  return b.toString();
}

Future<_GhResponse> _ghRequest(
  String method,
  String url, {
  required String token,
  Object? jsonBody,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request =
        await client.openUrl(method, Uri.parse(url)).timeout(timeout);
    request.headers.set(HttpHeaders.userAgentHeader, 'Pho-Community-DevTools');
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    if (jsonBody != null) {
      final bytes = utf8.encode(jsonEncode(jsonBody));
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      request.headers.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close().timeout(timeout);
    final text =
        await response.transform(utf8.decoder).join().timeout(timeout);
    return _GhResponse(response.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

/// GitHub REST 调用结果。
class _GhResponse {
  const _GhResponse(this.status, this.body);

  final int status;
  final String body;
}

String _ghMessage(String body) {
  try {
    final map = jsonDecode(body);
    if (map is Map && map['message'] != null) return map['message'].toString();
  } catch (_) {
    // 落到下面的截断
  }
  return body.length > 160 ? '${body.substring(0, 160)}…' : body;
}

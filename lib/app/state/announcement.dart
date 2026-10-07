import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:img_syncer/app/state/update_checker.dart' show extractVersion;
import 'package:img_syncer/core/net/text_fetch.dart';

/// 「启动时检查公告」的持久化 key（`false` = 默认开启）。
const String announcementCheckPrefKey = 'announcement_check_disabled';

/// 已读公告 id 的持久化 key（逗号分隔，只保留最近若干条）。
const String announcementSeenIdsKey = 'announcement_seen_ids';

/// 公告源，按优先级依次尝试。
///
/// 顺序的取舍（实测结论写在每条后面）：
/// 1. `raw.githubusercontent.com` —— push 即生效，缓存仅 5 分钟，内容最新；
/// 2. `gcore.jsdelivr.net` —— jsDelivr 的另一组节点，缓存比 cdn 主域名新，国内可达性好；
/// 3. `github.com/.../raw/main/...` —— 走 GitHub 主域，raw 域名被污染时往往仍可访问；
/// 4. `cdn.jsdelivr.net` —— 国内可达性最好，但 `@main` 的分支解析最长会被缓存 12 小时，
///    容易拿到旧版本，所以排在 gcore 之后；
/// 5. GitHub Pages —— 需要在仓库 Settings → Pages 里开一次；未开启时是 404，自动跳过。
///
/// 每次启动会**并发**请求全部源，再按上述优先级取第一个「返回了合法 JSON」的结果：
/// 既不会因为某条源被墙而卡住启动，也不会让带长缓存的源盖掉最新内容。
const List<String> announcementSources = <String>[
  'https://raw.githubusercontent.com/ZenithLiteAura/Pho_Community/main/docs/announcement.json',
  'https://gcore.jsdelivr.net/gh/ZenithLiteAura/Pho_Community@main/docs/announcement.json',
  'https://github.com/ZenithLiteAura/Pho_Community/raw/main/docs/announcement.json',
  'https://cdn.jsdelivr.net/gh/ZenithLiteAura/Pho_Community@main/docs/announcement.json',
  'https://zenithliteaura.github.io/Pho_Community/announcement.json',
];

/// 公告级别。`critical` 为强制展示：点遮罩与返回键都无法关闭，只能点按钮确认。
enum AnnouncementLevel {
  info,
  warning,
  critical;

  static AnnouncementLevel parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'critical':
      case 'urgent':
        return AnnouncementLevel.critical;
      case 'warning':
      case 'warn':
        return AnnouncementLevel.warning;
      default:
        return AnnouncementLevel.info;
    }
  }
}

/// 一条公告（支持中英双语，按系统语言挑选，缺失时互相兜底）。
@immutable
class Announcement {
  const Announcement({
    required this.id,
    required this.level,
    required this.title,
    required this.body,
    this.url,
    this.startAt,
    this.endAt,
    this.minVersion,
    this.maxVersion,
    this.once = true,
  });

  /// 唯一标识：换 id 才会再次弹出（`once` 为 true 时）。
  final String id;

  final AnnouncementLevel level;

  final LocalizedText title;
  final LocalizedText body;

  /// 可选的详情/下载链接。
  final String? url;

  /// 生效窗口（可选，按 UTC 比较）。
  final DateTime? startAt;
  final DateTime? endAt;

  /// 版本区间（可选，闭区间；例如 minVersion=3.4 时只有 3.4 及以后能看到）。
  final String? minVersion;
  final String? maxVersion;

  /// true = 同一 id 只弹一次。
  final bool once;

  /// `critical` 不可通过遮罩/返回键关闭。
  bool get dismissible => level != AnnouncementLevel.critical;

  /// 当前时刻 + 当前应用版本是否命中这条公告。
  bool matches({required DateTime now, required String appVersion}) {
    final t = now.toUtc();
    final start = startAt?.toUtc();
    if (start != null && t.isBefore(start)) return false;
    final end = endAt?.toUtc();
    if (end != null && t.isAfter(end)) return false;

    // 版本号解析失败时不做区间限制，避免因为写错版本号而整条公告失效。
    final current = extractVersion(appVersion);
    if (current == null) return true;
    if (minVersion != null && _compare(current, minVersion!) < 0) return false;
    if (maxVersion != null && _compare(current, maxVersion!) > 0) return false;
    return true;
  }

  /// 从 JSON 文本解析；`enabled` 非 true、id 为空或 JSON 非法时返回 null。
  static Announcement? parse(String rawJson) {
    Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);

    if (map['enabled'] != true) return null;

    final id = (map['id'] ?? '').toString().trim();
    if (id.isEmpty) return null;

    final title = LocalizedText.parse(map['title']);
    final body = LocalizedText.parse(map['body']);
    if (title.isEmpty && body.isEmpty) return null;

    final url = (map['url'] ?? '').toString().trim();

    return Announcement(
      id: id,
      level: AnnouncementLevel.parse(map['level']),
      title: title,
      body: body,
      url: url.isEmpty ? null : url,
      startAt: _parseDate(map['startAt']),
      endAt: _parseDate(map['endAt']),
      minVersion: _parseVersion(map['minVersion']),
      maxVersion: _parseVersion(map['maxVersion']),
      once: map['once'] is bool ? map['once'] as bool : true,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String? _parseVersion(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return extractVersion(s);
  }

  static int _compare(String a, String b) {
    final pa = a.split('.').map(int.parse).toList();
    final pb = b.split('.').map(int.parse).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va > vb ? 1 : -1;
    }
    return 0;
  }
}

/// 双语文本。也允许写成单个字符串（中英共用）。
@immutable
class LocalizedText {
  const LocalizedText({this.zh, this.en});

  final String? zh;
  final String? en;

  static LocalizedText parse(Object? raw) {
    if (raw is String) return LocalizedText(zh: raw, en: raw);
    if (raw is Map) {
      return LocalizedText(
        zh: _nonEmpty(raw['zh']),
        en: _nonEmpty(raw['en']),
      );
    }
    return const LocalizedText();
  }

  static String? _nonEmpty(Object? v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  bool get isEmpty => (zh ?? '').isEmpty && (en ?? '').isEmpty;

  String resolve(Locale locale) {
    final preferZh = locale.languageCode.toLowerCase() == 'zh';
    final first = preferZh ? zh : en;
    final second = preferZh ? en : zh;
    return (first ?? second ?? '').trim();
  }
}

/// 全部源的汇总结果：区分「源全挂」和「拿到了但没开启」，开发者选项要据此给出原因。
@immutable
class AnnouncementFetchReport {
  const AnnouncementFetchReport({
    required this.anySourceUsable,
    this.announcement,
  });

  /// 是否至少有一条源返回了合法 JSON。
  final bool anySourceUsable;

  /// 解析出的公告（enabled 非 true 时为 null）。
  final Announcement? announcement;
}

/// 公告判定原因（开发者选项里用来解释「为什么没弹」）。
enum AnnouncementGateReason {
  /// 会弹。
  willShow,

  /// 所有源都不可用（网络/被墙/404）。
  allSourcesFailed,

  /// 源可用，但云端 enabled 不是 true（没有正在生效的公告）。
  notEnabled,

  /// 不在 startAt / endAt 生效窗口内。
  outsideWindow,

  /// 与当前版本的 minVersion / maxVersion 不匹配。
  versionMismatch,

  /// 该 id 已读过（once=true）。
  alreadySeen,
}

/// 判定结果。
@immutable
class AnnouncementGateResult {
  const AnnouncementGateResult({required this.willShow, required this.reason, this.announcement});

  final bool willShow;
  final AnnouncementGateReason reason;
  final Announcement? announcement;
}

/// 公告判定门：把「真实会不会弹」的判定抽成纯逻辑，便于单测与开发者选项复用。
class AnnouncementGate {
  AnnouncementGate._();

  static AnnouncementGateResult evaluate({
    required Announcement? announcement,
    required bool anySourceUsable,
    required DateTime now,
    required String appVersion,
    required Set<String> seenIds,
  }) {
    if (!anySourceUsable) {
      return const AnnouncementGateResult(
          willShow: false, reason: AnnouncementGateReason.allSourcesFailed);
    }
    final a = announcement;
    if (a == null) {
      return const AnnouncementGateResult(
          willShow: false, reason: AnnouncementGateReason.notEnabled);
    }

    final t = now.toUtc();
    final start = a.startAt?.toUtc();
    if (start != null && t.isBefore(start)) {
      return AnnouncementGateResult(
          willShow: false, reason: AnnouncementGateReason.outsideWindow, announcement: a);
    }
    final end = a.endAt?.toUtc();
    if (end != null && t.isAfter(end)) {
      return AnnouncementGateResult(
          willShow: false, reason: AnnouncementGateReason.outsideWindow, announcement: a);
    }
    if (!a.matches(now: now, appVersion: appVersion)) {
      return AnnouncementGateResult(
          willShow: false, reason: AnnouncementGateReason.versionMismatch, announcement: a);
    }
    if (a.once && seenIds.contains(a.id)) {
      return AnnouncementGateResult(
          willShow: false, reason: AnnouncementGateReason.alreadySeen, announcement: a);
    }
    return AnnouncementGateResult(
        willShow: true, reason: AnnouncementGateReason.willShow, announcement: a);
  }
}

/// 某个公告源的返回值：区分「没拿到」（failed）和「拿到了但是关闭状态」（ok + null）。
@immutable
class AnnouncementFetch {
  const AnnouncementFetch({required this.ok, this.announcement});

  final bool ok;
  final Announcement? announcement;
}

/// 并发请求全部公告源，按 [announcementSources] 的优先级取第一个合法结果。
///
/// 全部源都失败时返回 null（静默）；成功但公告未开启时同样返回 null。
Future<Announcement?> fetchAnnouncement({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final report = await fetchAnnouncementReport(timeout: timeout);
  return report.announcement;
}

/// 同 [fetchAnnouncement]，但保留「是否至少有一条源可用」的信息。
Future<AnnouncementFetchReport> fetchAnnouncementReport({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final results = await Future.wait(
    announcementSources.map((url) => _fetchOne(url, timeout)),
  );
  for (final r in results) {
    if (r.ok) {
      return AnnouncementFetchReport(
        anySourceUsable: true,
        announcement: r.announcement,
      );
    }
  }
  return const AnnouncementFetchReport(anySourceUsable: false);
}

Future<AnnouncementFetch> _fetchOne(String url, Duration timeout) async {
  final text = await fetchText(url, timeout: timeout);
  if (text == null) return const AnnouncementFetch(ok: false);
  final announcement = Announcement.parse(text);
  // 能解析出 JSON 结构（含 enabled:false）就算这条源可用，不再回退到更旧的缓存。
  final looksLikeJson = text.trimLeft().startsWith('{');
  return AnnouncementFetch(ok: looksLikeJson, announcement: announcement);
}

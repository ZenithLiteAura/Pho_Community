import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// 单条 WebDAV 配置。
///
/// 每条配置独立保存地址、账号、根路径与 TLS 开关；同一时间只有一条
/// 处于「生效」状态（由 [WebdavConfigStore] 的 active id 决定）。
class WebdavConfig {
  WebdavConfig({
    required this.id,
    required this.name,
    this.url = '',
    this.username = '',
    this.password = '',
    this.rootPath = '',
    this.insecure = true,
  });

  /// 身份标识：重命名/改名不影响它，列表操作以它为准。
  final String id;

  /// 展示名（用户可改）。
  String name;
  String url;
  String username;
  String password;
  String rootPath;
  bool insecure;

  /// 是否已具备生效条件：地址与根路径都填了。
  bool get isUsable => url.trim().isNotEmpty && rootPath.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'username': username,
        'password': password,
        'rootPath': rootPath,
        'insecure': insecure,
      };

  static WebdavConfig fromJson(Map<String, dynamic> m) {
    return WebdavConfig(
      id: (m['id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      url: (m['url'] ?? '').toString(),
      username: (m['username'] ?? '').toString(),
      password: (m['password'] ?? '').toString(),
      rootPath: (m['rootPath'] ?? '').toString(),
      insecure: m['insecure'] is bool ? m['insecure'] as bool : true,
    );
  }
}

/// WebDAV 多配置的读写、一次性迁移与命名工具。
///
/// 纯逻辑、不依赖 BuildContext，便于单测（`SharedPreferences.setMockInitialValues`）。
///
/// 存储键：
///  - [configsKey]        —— 配置数组（JSON），顺序即下拉顺序
///  - [activeIdKey]       —— 当前生效配置的 id
///  - 旧键（[legacyUrlKey] 等）—— 仅作为迁移来源，迁移后**保留不删**，便于回退
class WebdavConfigStore {
  WebdavConfigStore._();

  static const String configsKey = 'webdav_configs';
  static const String activeIdKey = 'webdav_active_config_id';

  // ── 旧键（v3.3 及以前的「主 / 备份」两槽位）──
  static const String legacyUrlKey = 'webdav_url';
  static const String legacyUserKey = 'webdav_username';
  static const String legacyPassKey = 'webdav_password';
  static const String legacyRootKey = 'webdav_root_path';
  static const String legacyInsecureKey = 'webdav_insecure';
  static const String legacyUrl2Key = 'webdav_url2';
  static const String legacyUser2Key = 'webdav_username2';
  static const String legacyPass2Key = 'webdav_password2';
  static const String legacyRoot2Key = 'webdav_root_path2';
  static const String legacyInsecure2Key = 'webdav_insecure2';

  static const String _idPrefix = 'webdav-cfg-';
  static final Random _rand = Random();

  static String _newId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final salt = _rand.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return '$_idPrefix$ts-$salt';
  }

  /// 读取配置列表。
  ///
  /// - 键不存在 → 执行一次性迁移（旧主/备键 → 配置1/配置2），并写回；
  ///   旧键均为空时迁移结果为空数组（不在此处补「配置1」，避免读操作产生副作用）。
  /// - 键存在但内容损坏 → 返回空数组（不覆盖存储，交由调用方决定）。
  static Future<List<WebdavConfig>> load([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(configsKey);
    if (raw == null) {
      final migrated = await _migrate(p);
      return migrated;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <WebdavConfig>[];
      return decoded
          .whereType<Map>()
          .map((e) => WebdavConfig.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <WebdavConfig>[];
    }
  }

  /// 一次性迁移：把旧「主 / 备份」两槽位转成「配置1」「配置2」。
  ///
  /// 仅当 [configsKey] 不存在时由 [load] 调用，因此天然幂等。
  static Future<List<WebdavConfig>> _migrate(SharedPreferences p) async {
    final list = <WebdavConfig>[];

    final url = p.getString(legacyUrlKey) ?? '';
    final root = p.getString(legacyRootKey) ?? '';
    if (url.isNotEmpty || root.isNotEmpty) {
      list.add(WebdavConfig(
        id: _newId(),
        name: '配置1',
        url: url,
        username: p.getString(legacyUserKey) ?? '',
        password: p.getString(legacyPassKey) ?? '',
        rootPath: root,
        insecure: p.getBool(legacyInsecureKey) ?? true,
      ));
    }

    final url2 = p.getString(legacyUrl2Key) ?? '';
    final root2 = p.getString(legacyRoot2Key) ?? '';
    if (url2.isNotEmpty || root2.isNotEmpty) {
      list.add(WebdavConfig(
        id: _newId(),
        name: '配置2',
        url: url2,
        username: p.getString(legacyUser2Key) ?? '',
        password: p.getString(legacyPass2Key) ?? '',
        rootPath: root2,
        insecure: p.getBool(legacyInsecure2Key) ?? true,
      ));
    }

    await save(list, p);
    if (list.isNotEmpty) {
      await saveActiveId(list.first.id, p);
    }
    return list;
  }

  /// 持久化配置列表。
  static Future<void> save(
    List<WebdavConfig> list, [
    SharedPreferences? prefs,
  ]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      configsKey,
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
  }

  /// 当前生效配置的 id；未设置或指向已不存在的配置时返回 null。
  static Future<String?> loadActiveId([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getString(activeIdKey);
  }

  /// 写入当前生效配置的 id（null 表示无生效配置）。
  static Future<void> saveActiveId(String? id, [SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(activeIdKey);
    } else {
      await p.setString(activeIdKey, id);
    }
  }

  /// 从列表中取出生效配置：active id 命中则用它，否则回退到第一条。
  static WebdavConfig? activeOf(List<WebdavConfig> list, String? activeId) {
    if (list.isEmpty) return null;
    if (activeId != null) {
      for (final c in list) {
        if (c.id == activeId) return c;
      }
    }
    return list.first;
  }

  /// 计算下一个默认配置名：`<prefix>N`，N 取最小未被占用的正整数。
  ///
  /// 例：已有「配置1」「配置3」→ 返回「配置2」。
  static String nextDefaultName(List<WebdavConfig> existing, String prefix) {
    final re = RegExp('^${RegExp.escape(prefix)}(\\d+)\$');
    final used = <int>{};
    for (final c in existing) {
      final m = re.firstMatch(c.name.trim());
      if (m != null) {
        final n = int.tryParse(m.group(1)!);
        if (n != null) used.add(n);
      }
    }
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    return '$prefix$n';
  }

  /// 新建一条空配置（仅本地对象，不落盘）。
  static WebdavConfig createConfig(String name) =>
      WebdavConfig(id: _newId(), name: name);
}
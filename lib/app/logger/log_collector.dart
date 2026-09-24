import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 日志级别（数值越大越严重）。
///
/// 采集时按级别过滤：选择某档即采集「该档及以上」的日志。
enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warning(2, 'WARNING'),
  error(3, 'ERROR');

  const LogLevel(this.severity, this.label);

  final int severity;
  final String label;

  /// 本条级别是否达到过滤线 [min]。
  bool passes(LogLevel min) => severity >= min.severity;
}

/// 被采集的一条日志。
class LogEntry {
  LogEntry(this.time, this.level, this.message);

  final DateTime time;
  final LogLevel level;
  final String message;

  /// 导出用的单行文本：`[2026-09-22 22:30:15] [INFO] ...`
  String format() => '[${formatTimestamp(time)}] [${level.label}] $message';
}

/// 历史上的一次采集记录（已落盘为文件）。
class LogSessionMeta {
  LogSessionMeta({
    required this.path,
    required this.startedAt,
    required this.sizeBytes,
  });

  final String path;
  final DateTime startedAt;
  final int sizeBytes;

  String get fileName => path.split(Platform.pathSeparator).last;

  /// 可读大小。
  String get readableSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// `yyyy-MM-dd HH:mm:ss` 时间戳（不依赖 intl，便于在纯 Dart 环境测试）。
String formatTimestamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// `yyyyMMdd-HHmmss`（用于文件名，字典序即时间序）。
String formatFileStamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

/// 日志采集器。
///
/// 语义：**点击「开始采集」之后**产生的日志才进入本次会话缓冲；开始之前的
/// 日志不会被采集。停止时把会话写入 `documents/pho-logs/`，并只保留最近
/// [maxHistory] 条历史记录。
///
/// 之所以独立于 [LoggerService]：日志本身一直在产生（并打到 logcat），
/// 采集只决定"要不要留一份下来导出"。
class LogCollector extends ChangeNotifier {
  LogCollector._();

  static final LogCollector instance = LogCollector._();

  /// 历史记录保留条数（用户要求 5-10 条，取 8）。
  static const int maxHistory = 8;

  /// 单条日志的最大字符数，超长内容截断，避免一行撑爆导出文件。
  static const int maxEntryChars = 4000;

  /// 预览刷新节流间隔：日志可能密集产生，逐条 notify 会让设置页反复重建。
  static const Duration _notifyThrottle = Duration(milliseconds: 200);

  static const String _dirName = 'pho-logs';

  bool _collecting = false;
  LogLevel _level = LogLevel.info;
  final List<LogEntry> _entries = [];
  DateTime? _startedAt;
  List<LogSessionMeta> _history = const [];
  bool _historyLoaded = false;
  Timer? _notifyTimer;

  bool get collecting => _collecting;
  LogLevel get level => _level;
  DateTime? get startedAt => _startedAt;
  int get entryCount => _entries.length;

  /// 当前会话日志（只读视图）。
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// 已保存的历史记录，新 → 旧。
  List<LogSessionMeta> get history => List.unmodifiable(_history);

  bool get historyLoaded => _historyLoaded;

  /// 开始采集。会清空上一次的会话缓冲 —— 「只采集开始之后的日志」。
  void start({LogLevel? level}) {
    if (level != null) _level = level;
    _entries.clear();
    _startedAt = DateTime.now();
    _collecting = true;
    notifyListeners();
  }

  /// 仅清空缓冲、不落盘（用于放弃当前会话）。
  void discard() {
    _entries.clear();
    _startedAt = null;
    _collecting = false;
    notifyListeners();
  }

  /// 调整采集级别。采集过程中也可改，立即生效。
  void setLevel(LogLevel level) {
    if (_level == level) return;
    _level = level;
    notifyListeners();
  }

  /// 记录一条日志。未采集、或级别低于过滤线时直接丢弃。
  ///
  /// 由 [LoggerService] 调用，因此必须足够轻量。
  void record(LogLevel level, String message) {
    if (!_collecting) return;
    if (!level.passes(_level)) return;
    _entries.add(LogEntry(
      DateTime.now(),
      level,
      message.length > maxEntryChars
          ? '${message.substring(0, maxEntryChars)}…（已截断）'
          : message,
    ));
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(_notifyThrottle, () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  /// 生成导出文本（含表头）。
  String buildExportText() {
    final startedAt = _startedAt;
    final buf = StringBuffer()
      ..writeln('# Pho 日志采集')
      ..writeln('# 会话开始：${startedAt == null ? "-" : formatTimestamp(startedAt)}')
      ..writeln('# 采集级别：${_level.label} 及以上')
      ..writeln('# 共 ${_entries.length} 条')
      ..writeln();
    for (final e in _entries) {
      buf.writeln(e.format());
    }
    return buf.toString();
  }

  /// 导出文件名建议，如 `pho-log-20260922-223015.txt`。
  String suggestFileName({DateTime? at}) =>
      'pho-log-${formatFileStamp(at ?? _startedAt ?? DateTime.now())}.txt';

  /// 停止采集并把会话写入历史；返回落盘路径，失败返回 null。
  Future<String?> stop() async {
    if (!_collecting) return null;
    _collecting = false;
    _notifyTimer?.cancel();
    _notifyTimer = null;

    final text = buildExportText();
    final startedAt = _startedAt ?? DateTime.now();

    String? savedPath;
    try {
      final dir = await _logDir();
      final file = File('${dir.path}/${suggestFileName(at: startedAt)}');
      await file.writeAsString(text);
      savedPath = file.path;
      await _pruneHistory(dir);
      await refreshHistory();
    } catch (e) {
      // 落盘失败不影响主流程，也不阻断 UI 状态切换
      debugPrint('save log session failed: $e');
    }

    notifyListeners();
    return savedPath;
  }

  /// 读取历史记录列表（新 → 旧）。
  Future<void> refreshHistory() async {
    try {
      final dir = await _logDir();
      final files = await _listLogFiles(dir);
      _history = await Future.wait(files.map((f) async {
        final stat = await f.stat();
        return LogSessionMeta(
          path: f.path,
          startedAt: stat.modified,
          sizeBytes: stat.size,
        );
      }));
    } catch (e) {
      debugPrint('load log history failed: $e');
      _history = const [];
    }
    _historyLoaded = true;
    notifyListeners();
  }

  /// 只保留最近 [maxHistory] 条历史文件。
  Future<void> _pruneHistory(Directory dir) async {
    final files = await _listLogFiles(dir);
    if (files.length <= maxHistory) return;
    for (final f in files.sublist(maxHistory)) {
      try {
        await f.delete();
      } catch (e) {
        debugPrint('prune log file failed: ${f.path} $e');
      }
    }
  }

  /// 列出日志文件，按文件名倒序（文件名含时间戳，字典序即时间序）。
  Future<List<File>> _listLogFiles(Directory dir) async {
    final entries = await dir.list().toList();
    final files = entries
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// 读取某个历史文件的文本内容（导出用）。
  Future<String?> readSession(String path) async {
    try {
      return await File(path).readAsString();
    } catch (e) {
      debugPrint('read log session failed: $path $e');
      return null;
    }
  }

  /// 删除单条历史记录。
  Future<void> deleteSession(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('delete log session failed: $path $e');
    }
    await refreshHistory();
  }

  /// 清空全部历史记录。
  Future<void> clearHistory() async {
    try {
      final dir = await _logDir();
      for (final f in await _listLogFiles(dir)) {
        try {
          await f.delete();
        } catch (e) {
          debugPrint('delete log file failed: ${f.path} $e');
        }
      }
    } catch (e) {
      debugPrint('clear log history failed: $e');
    }
    await refreshHistory();
  }

  Future<Directory> _logDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_dirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }
}
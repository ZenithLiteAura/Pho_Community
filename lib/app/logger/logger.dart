import 'package:intl/intl.dart';

import 'package:img_syncer/app/logger/log_collector.dart';

final logger = LoggerService();

/// 应用内日志服务。
///
/// 日志有两个去处：
///  1. 内存环形缓冲 [logs]（供调试查看，见 [maxRetainedLogs]）；
///  2. [LogCollector]：**仅当用户开启采集时**才会留下可导出的一份。
///
/// 分级说明：`addLog` 为 info 级（既有 39 处调用点保持不变），
/// 另提供 debug / warning / error 三级；采集页按级别过滤。
class LoggerService {
  final List<String> _logs = [];

  /// 内存中保留的日志条数上限（滚动淘汰）。
  ///
  /// 原先该列表无上限，长时间运行会持续占用内存。
  static const int maxRetainedLogs = 5000;

  /// info 级（默认）。
  void addLog(String log) => _record(LogLevel.info, log);

  /// debug 级：细节排查用，采集级别选 debug 时才会被采集。
  void addDebug(String log) => _record(LogLevel.debug, log);

  /// warning 级：可恢复的异常（如重试、降级）。
  void addWarning(String log) => _record(LogLevel.warning, log);

  /// error 级：失败。
  void addError(String log) => _record(LogLevel.error, log);

  void _record(LogLevel level, String log) {
    final DateFormat format = DateFormat("yyyy-MM-dd HH:mm:ss");
    final logStr = "[${format.format(DateTime.now())}] $log";
    _logs.add(logStr);
    if (_logs.length > maxRetainedLogs) {
      _logs.removeRange(0, _logs.length - maxRetainedLogs);
    }
    // 采集器：未开启采集时内部立即返回，开销可忽略。
    LogCollector.instance.record(level, log);
    print(logStr);
  }

  List<String> get logs => _logs;
}
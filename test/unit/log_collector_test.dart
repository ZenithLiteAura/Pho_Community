import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/logger/log_collector.dart';

/// 日志采集契约。
///
/// 重点锁住三件事：
///  1. **只采集「开始采集」之后的日志**（开始前的必须被丢弃）；
///  2. 级别过滤按「该级别及以上」生效，且采集中可随时改；
///  3. 历史只保留最近 8 条（用户要求 5-10 条）。
void main() {
  final collector = LogCollector.instance;

  setUp(() {
    // 单例状态跨用例共享，先复位到「未采集 + info」。
    collector.discard();
    collector.setLevel(LogLevel.info);
  });

  group('LogLevel', () {
    test('severity 依次递增', () {
      expect(LogLevel.debug.severity, lessThan(LogLevel.info.severity));
      expect(LogLevel.info.severity, lessThan(LogLevel.warning.severity));
      expect(LogLevel.warning.severity, lessThan(LogLevel.error.severity));
    });

    test('passes：达到或超过过滤线才通过', () {
      expect(LogLevel.error.passes(LogLevel.info), isTrue);
      expect(LogLevel.info.passes(LogLevel.info), isTrue);
      expect(LogLevel.debug.passes(LogLevel.info), isFalse);
      expect(LogLevel.warning.passes(LogLevel.error), isFalse);
    });
  });

  group('采集开关语义', () {
    test('未开始采集时日志被丢弃', () {
      collector.record(LogLevel.error, 'not collected');

      expect(collector.collecting, isFalse);
      expect(collector.entryCount, 0);
    });

    test('只有开始之后的日志进入本次会话', () {
      collector.record(LogLevel.error, 'before start'); // 应被丢弃
      collector.start();
      collector.record(LogLevel.error, 'after start');

      expect(collector.collecting, isTrue);
      expect(collector.entryCount, 1);
      expect(collector.entries.single.message, 'after start');
    });

    test('重新开始会清空上一次会话', () {
      collector.start();
      collector.record(LogLevel.error, 'first session');
      expect(collector.entryCount, 1);

      collector.start();

      expect(collector.entryCount, 0,
          reason: '「只采集开始之后的日志」——上一轮内容不能带进来');
    });

    test('discard 清空并停止采集', () {
      collector.start();
      collector.record(LogLevel.error, 'x');
      collector.discard();

      expect(collector.collecting, isFalse);
      expect(collector.entryCount, 0);
      expect(collector.startedAt, isNull);
    });
  });

  group('级别过滤', () {
    test('过滤线以下的日志被丢弃', () {
      collector.start(level: LogLevel.warning);
      collector.record(LogLevel.debug, 'd');
      collector.record(LogLevel.info, 'i');
      collector.record(LogLevel.warning, 'w');
      collector.record(LogLevel.error, 'e');

      expect(collector.entryCount, 2);
      expect(
        collector.entries.map((e) => e.level).toList(),
        [LogLevel.warning, LogLevel.error],
      );
    });

    test('采集中调整级别立即生效', () {
      collector.start(level: LogLevel.error);
      collector.record(LogLevel.warning, 'w1');
      expect(collector.entryCount, 0);

      collector.setLevel(LogLevel.debug);
      collector.record(LogLevel.debug, 'd1');

      expect(collector.entryCount, 1);
      expect(collector.level, LogLevel.debug);
    });
  });

  group('导出文本', () {
    test('包含表头、级别标注与条数', () {
      collector.start(level: LogLevel.info);
      collector.record(LogLevel.warning, 'hello');

      final text = collector.buildExportText();

      expect(text.contains('# Pho 日志采集'), isTrue);
      expect(text.contains('# 采集级别：INFO 及以上'), isTrue);
      expect(text.contains('# 共 1 条'), isTrue);
      expect(text.contains('[WARNING] hello'), isTrue);
    });

    test('超长消息被截断，避免单行撑爆文件', () {
      collector.start(level: LogLevel.debug);
      collector.record(LogLevel.info, 'x' * (LogCollector.maxEntryChars + 100));

      final msg = collector.entries.single.message;

      expect(msg.length, lessThanOrEqualTo(LogCollector.maxEntryChars + 16));
      expect(msg.contains('已截断'), isTrue);
    });
  });

  group('时间戳与文件名', () {
    test('formatTimestamp 各字段补零', () {
      expect(formatTimestamp(DateTime(2026, 9, 22, 8, 5, 3)),
          '2026-09-22 08:05:03');
    });

    test('文件名字典序等价于时间序（历史排序依赖它）', () {
      final earlier = formatFileStamp(DateTime(2026, 9, 22, 8, 5, 3));
      final later = formatFileStamp(DateTime(2026, 9, 22, 12, 0, 0));

      expect(earlier, '20260922-080503');
      expect(earlier.compareTo(later), lessThan(0));
    });

    test('suggestFileName 由会话开始时间生成', () {
      collector.start();

      expect(
        collector.suggestFileName(at: DateTime(2026, 9, 22, 22, 30, 15)),
        'pho-log-20260922-223015.txt',
      );
    });

    test('LogEntry.format 形态', () {
      final entry = LogEntry(DateTime(2026, 9, 22, 22, 30, 15), LogLevel.error, 'boom');
      expect(entry.format(), '[2026-09-22 22:30:15] [ERROR] boom');
    });
  });

  group('历史保留策略', () {
    test('保留条数为 8（落在要求的 5-10 区间）', () {
      expect(LogCollector.maxHistory, inInclusiveRange(5, 10));
    });
  });
}
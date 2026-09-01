// 单测：锁住 sync_timer.dart 中定时同步（定时模式）的计算逻辑。
//
// 两个纯函数：
//   - parseScheduleTime("HH:mm", day)  -> 当天对应时刻或 null
//   - nextScheduleOccurrence(list, now) -> 下一次定时同步时刻或 null
//
// 不触碰平台通道；仅 import sync_timer.dart 复用其顶层函数。
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/sync_timer.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('parseScheduleTime', () {
    test('合法 "HH:mm" 解析为当天对应时刻', () {
      expect(parseScheduleTime('08:30', DateTime(2026, 8, 30)),
          DateTime(2026, 8, 30, 8, 30));
      expect(parseScheduleTime('00:00', DateTime(2026, 8, 30)),
          DateTime(2026, 8, 30, 0, 0));
      expect(parseScheduleTime('23:59', DateTime(2026, 8, 30)),
          DateTime(2026, 8, 30, 23, 59));
    });

    test('非法输入返回 null', () {
      expect(parseScheduleTime('25:00', DateTime(2026, 8, 30)), isNull);
      expect(parseScheduleTime('08:60', DateTime(2026, 8, 30)), isNull);
      expect(parseScheduleTime('-1:30', DateTime(2026, 8, 30)), isNull);
      expect(parseScheduleTime('abc', DateTime(2026, 8, 30)), isNull);
      expect(parseScheduleTime('8', DateTime(2026, 8, 30)), isNull);
      expect(parseScheduleTime('', DateTime(2026, 8, 30)), isNull);
      expect(parseScheduleTime('8:30:00', DateTime(2026, 8, 30)), isNull);
    });
  });

  group('nextScheduleOccurrence', () {
    final now = DateTime(2026, 8, 30, 12, 0, 0);

    test('空列表返回 null', () {
      expect(nextScheduleOccurrence([], now), isNull);
    });

    test('今天有未过的定时点时取最早者', () {
      expect(
        nextScheduleOccurrence(['20:00', '13:00', '08:00'], now),
        DateTime(2026, 8, 30, 13, 0),
      );
    });

    test('今天全部已过时取明天最早者', () {
      expect(
        nextScheduleOccurrence(['08:00', '10:30'], now),
        DateTime(2026, 8, 31, 8, 0),
      );
    });

    test('恰好等于 now 的时刻视为已过，取下一个', () {
      expect(
        nextScheduleOccurrence(['12:00', '18:00'], now),
        DateTime(2026, 8, 30, 18, 0),
      );
    });

    test('全部非法条目时返回 null', () {
      expect(nextScheduleOccurrence(['bad', '25:99'], now), isNull);
    });

    test('跨月边界正确（月底取次月第一天）', () {
      final lastDay = DateTime(2026, 8, 31, 23, 0);
      expect(
        nextScheduleOccurrence(['22:00'], lastDay),
        DateTime(2026, 9, 1, 22, 0),
      );
    });

    test('当天时间未过时不跨天', () {
      expect(
        nextScheduleOccurrence(['23:59'], DateTime(2026, 8, 30, 23, 0)),
        DateTime(2026, 8, 30, 23, 59),
      );
    });
  });
}

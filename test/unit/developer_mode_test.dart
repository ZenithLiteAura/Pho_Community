import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/state/developer_mode.dart';

void main() {
  group('verifyDeveloperPassword（只比对 MD5 摘要）', () {
    test('空密码不通过', () {
      expect(verifyDeveloperPassword(''), isFalse);
    });

    test('错误密码不通过', () {
      expect(verifyDeveloperPassword('not-the-password'), isFalse);
      expect(verifyDeveloperPassword('123456'), isFalse);
      expect(verifyDeveloperPassword(' '), isFalse);
      // 摘要本身不是明文，输入摘要当然也不该通过
      expect(verifyDeveloperPassword(developerPasswordMd5), isFalse);
    });

    test('实现就是「输入的 MD5」与内置摘要比较', () {
      for (final s in ['abc', 'Pho', '中文测试', 'a-b-c']) {
        final expected =
            md5.convert(utf8.encode(s)).toString() ==
                developerPasswordMd5.toLowerCase();
        expect(verifyDeveloperPassword(s), expected,
            reason: '对 "$s" 的判定应与 MD5 比对一致');
      }
    });

    test('内置摘要格式正确（32 位小写十六进制）', () {
      expect(developerPasswordMd5.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(developerPasswordMd5), isTrue);
    });
  });

  group('DeveloperTapGate', () {
    test('连续 7 次才触发，第 6 次不触发', () {
      final gate = DeveloperTapGate();
      final t0 = DateTime(2026, 10, 7, 12, 0, 0);
      var fired = false;
      for (var i = 1; i <= developerUnlockTapCount - 1; i++) {
        fired = gate.registerTap(t0.add(Duration(milliseconds: 100 * i)));
        expect(fired, isFalse, reason: '第 $i 次不应触发');
      }
      fired = gate.registerTap(
          t0.add(Duration(milliseconds: 100 * developerUnlockTapCount)));
      expect(fired, isTrue);
    });

    test('触发后自动清零', () {
      final gate = DeveloperTapGate();
      final t0 = DateTime(2026, 10, 7, 12, 0, 0);
      for (var i = 0; i < developerUnlockTapCount; i++) {
        gate.registerTap(t0.add(Duration(milliseconds: 50 * i)));
      }
      expect(gate.count, 0);
      expect(gate.registerTap(t0.add(const Duration(seconds: 1))), isFalse);
      expect(gate.count, 1);
    });

    test('间隔超过阈值会重新计数', () {
      final gate = DeveloperTapGate();
      final t0 = DateTime(2026, 10, 7, 12, 0, 0);
      for (var i = 0; i < developerUnlockTapCount - 1; i++) {
        gate.registerTap(t0.add(Duration(milliseconds: 50 * i)));
      }
      // 停手超过 developerUnlockTapGap 后再点，应从头开始
      final late = t0.add(developerUnlockTapGap + const Duration(seconds: 1));
      expect(gate.registerTap(late), isFalse);
      expect(gate.count, 1);
    });

    test('reset 清空计数', () {
      final gate = DeveloperTapGate();
      gate.registerTap(DateTime(2026, 10, 7));
      gate.registerTap(DateTime(2026, 10, 7, 0, 0, 1));
      expect(gate.count, 2);
      gate.reset();
      expect(gate.count, 0);
    });
  });
}

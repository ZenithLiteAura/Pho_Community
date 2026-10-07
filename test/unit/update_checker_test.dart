import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/state/update_checker.dart';

void main() {
  group('extractVersion', () {
    test('从带前后缀的 tag 中提取版本号', () {
      expect(extractVersion('v3.5-community'), '3.5');
      expect(extractVersion('3.4'), '3.4');
      expect(extractVersion('release-3.5.1'), '3.5.1');
      expect(extractVersion('V10'), '10');
    });

    test('无法解析时返回 null', () {
      expect(extractVersion('latest'), isNull);
      expect(extractVersion(''), isNull);
    });
  });

  group('isNewerVersion', () {
    test('更高版本判定为更新', () {
      expect(isNewerVersion('v3.5-community', '3.4'), isTrue);
      expect(isNewerVersion('3.4.1', '3.4'), isTrue);
      expect(isNewerVersion('4.0', '3.9.9'), isTrue);
      expect(isNewerVersion('3.10', '3.9'), isTrue);
    });

    test('相同或更低版本判定为不是更新', () {
      expect(isNewerVersion('v3.4-community', '3.4'), isFalse);
      expect(isNewerVersion('3.4.0', '3.4'), isFalse);
      expect(isNewerVersion('3.3', '3.4'), isFalse);
      expect(isNewerVersion('3.9', '3.10'), isFalse);
    });

    test('无法解析时不误报', () {
      expect(isNewerVersion('latest', '3.4'), isFalse);
      expect(isNewerVersion('v3.5', 'unknown'), isFalse);
    });
  });
}

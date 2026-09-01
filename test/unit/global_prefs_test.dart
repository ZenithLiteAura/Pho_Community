import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('enable_encrypt 旧 key 迁移', () {
    test('从 enalble_encrypt 旧 key 读取并迁移到 enable_encrypt', () async {
      SharedPreferences.setMockInitialValues({
        'enalble_encrypt': true,
      });

      final prefs = await SharedPreferences.getInstance();

      // 模拟 global.dart 中的迁移逻辑
      var enableEncrypt = prefs.getBool("enable_encrypt");
      if (enableEncrypt == null) {
        enableEncrypt = prefs.getBool("enalble_encrypt");
        if (enableEncrypt != null) {
          prefs.setBool("enable_encrypt", enableEncrypt);
          prefs.remove("enalble_encrypt");
        }
      }

      // 验证新 key 已写入，旧 key 已移除
      expect(prefs.getBool("enable_encrypt"), isTrue);
      expect(prefs.getBool("enalble_encrypt"), isNull);
    });

    test('新 key enable_encrypt 存在时直接读取，不迁移', () async {
      SharedPreferences.setMockInitialValues({
        'enable_encrypt': false,
        'enalble_encrypt': true, // 旧 key 存在但因新 key 已存在所以忽略
      });

      final prefs = await SharedPreferences.getInstance();

      var enableEncrypt = prefs.getBool("enable_encrypt");
      if (enableEncrypt == null) {
        enableEncrypt = prefs.getBool("enalble_encrypt");
        if (enableEncrypt != null) {
          prefs.setBool("enable_encrypt", enableEncrypt);
          prefs.remove("enalble_encrypt");
        }
      }

      // 验证使用的是新 key 的值
      expect(enableEncrypt, isFalse);
      // 旧 key 不应被移除（迁移逻辑未触发）
      expect(prefs.getBool("enalble_encrypt"), isTrue);
    });

    test('两个 key 都不存在时返回 null', () async {
      SharedPreferences.setMockInitialValues({});

      final prefs = await SharedPreferences.getInstance();

      var enableEncrypt = prefs.getBool("enable_encrypt");
      if (enableEncrypt == null) {
        enableEncrypt = prefs.getBool("enalble_encrypt");
        if (enableEncrypt != null) {
          prefs.setBool("enable_encrypt", enableEncrypt);
          prefs.remove("enalble_encrypt");
        }
      }

      expect(enableEncrypt, isNull);
    });
  });
}

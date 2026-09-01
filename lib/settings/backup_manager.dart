import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 备份 / 恢复管理器。
///
/// - 备份：将全部 SharedPreferences 配置序列化为 settings.json 并打包为 zip；
/// - 恢复：读取 zip 中的 settings.json，按原始类型写回 SharedPreferences。
///
/// 注意：备份包含云存储凭据等敏感配置，请妥善保管备份文件。
class BackupManager {
  BackupManager._();

  static const String _settingsEntry = 'settings.json';

  /// 生成完整配置备份的 zip 字节。
  static Future<Uint8List> createBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      final value = _encodeValue(key, prefs);
      if (value != null) {
        data[key] = value;
      }
    }
    final archive = Archive()
      ..addFile(ArchiveFile.string(_settingsEntry, jsonEncode(data)));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static Map<String, dynamic>? _encodeValue(
    String key,
    SharedPreferences prefs,
  ) {
    // SharedPreferences 的 getX 在键类型不匹配时会抛类型转换异常，
    // 因此逐类型探测并用 try/catch 兜底。
    try {
      final s = prefs.getString(key);
      if (s != null) return {'t': 's', 'v': s};
    } catch (_) {}
    try {
      final i = prefs.getInt(key);
      if (i != null) return {'t': 'i', 'v': i};
    } catch (_) {}
    try {
      final b = prefs.getBool(key);
      if (b != null) return {'t': 'b', 'v': b};
    } catch (_) {}
    try {
      final sl = prefs.getStringList(key);
      if (sl != null) return {'t': 'sl', 'v': sl};
    } catch (_) {}
    return null;
  }

  /// 从 zip 字节恢复配置，返回恢复的键数量。
  static Future<int> restore(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.files.where((f) => f.name == _settingsEntry).toList();
    if (file.isEmpty) {
      throw const FormatException('missing settings.json');
    }
    final data =
        jsonDecode(utf8.decode(file.first.content)) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    var count = 0;
    for (final entry in data.entries) {
      final key = entry.key;
      final raw = entry.value;
      if (raw is! Map<String, dynamic>) continue;
      final type = raw['t'];
      final value = raw['v'];
      switch (type) {
        case 's':
          if (value is String) {
            await prefs.setString(key, value);
            count++;
          }
          break;
        case 'i':
          if (value is int) {
            await prefs.setInt(key, value);
            count++;
          }
          break;
        case 'b':
          if (value is bool) {
            await prefs.setBool(key, value);
            count++;
          }
          break;
        case 'sl':
          if (value is List) {
            await prefs.setStringList(key, value.cast<String>());
            count++;
          }
          break;
      }
    }
    return count;
  }
}

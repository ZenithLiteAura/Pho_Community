import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:photo_manager/photo_manager.dart';

/// 文件哈希工具：用于「已上传」验证。
///
/// 为避免对视频等大文件做全量哈希，采用「简单运算」策略：
/// 对 文件大小 + 文件头 1MB + 文件尾 1MB 计算 MD5。
/// 对照片/视频去重足够可靠，且读取量恒定（≤2MB）。
class FileHash {
  FileHash._();

  /// 采样窗口大小。
  static const int _sampleSize = 1024 * 1024; // 1MB

  /// 计算某个相册资产文件的采样哈希。
  /// 文件不可读时返回 null（调用方应视为未上传、走正常上传流程）。
  static Future<String?> ofAsset(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return null;
    return ofFile(file);
  }

  /// 计算文件的采样哈希：md5("$size|$head|$tail")。
  static Future<String?> ofFile(File file) async {
    try {
      final length = await file.length();
      final raf = await file.open();
      try {
        final headLen = length < _sampleSize ? length : _sampleSize;
        final tailLen = length < _sampleSize * 2
            ? length - headLen
            : _sampleSize;
        final head = Uint8List(headLen);
        final tail = Uint8List(tailLen);
        await raf.readInto(head, 0);
        if (tailLen > 0) {
          await raf.setPosition(length - tailLen);
          await raf.readInto(tail, 0);
        }
        final digest = md5.convert([
          ...utf8.encode('$length|'),
          ...head,
          ...tail,
        ]);
        return digest.toString();
      } finally {
        await raf.close();
      }
    } catch (e) {
      return null;
    }
  }
}

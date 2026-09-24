import 'dart:io';

import 'package:flutter/services.dart';
import 'package:img_syncer/app/logger/logger.dart';
import 'package:path/path.dart';

bool isVideoByPath(String path) {
  if (extension(path).toLowerCase() == ".aes") {
    path = basenameWithoutExtension(path);
  }
  switch (extension(path).toLowerCase()) {
    case ".mp4":
    case ".avi":
    case ".mov":
    case ".mkv":
    case ".flv":
    case ".rmvb":
    case ".rm":
    case ".3gp":
    case ".wmv":
    case ".mpeg":
    case ".mpg":
    case ".webm":
      return true;
  }
  return false;
}

String? mimeTypeByExtension(String ext) {
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'bmp':
      return 'image/bmp';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'dng':
      return 'image/x-adobe-dng';
    case 'tif':
    case 'tiff':
      return 'image/tiff';
    case 'cr2':
      return 'image/x-canon-cr2';
    case 'nef':
      return 'image/x-nikon-nef';
    case 'arw':
      return 'image/x-sony-arw';
    case 'rw2':
      return 'image/x-panasonic-rw2';
    case 'orf':
      return 'image/x-olympus-orf';
    case 'pef':
      return 'image/x-pentax-pef';
    case 'raf':
      return 'image/x-fuji-raf';
    case 'x3f':
      return 'image/x-sigma-x3f';
    case 'srw':
      return 'image/x-samsung-srw';
    case ".mp4":
      return "video/mp4";
    case ".avi":
      return "video/avi";
    case ".mov":
      return "video/mov";
    case ".mkv":
      return "video/mkv";
    case ".flv":
      return "video/flv";
    case ".rmvb":
      return "video/rmvb";
    case ".rm":
      return "video/rm";
    case ".3gp":
      return "video/3gp";
    case ".wmv":
      return "video/wmv";
    case ".mpeg":
      return "video/mpeg";
    case ".mpg":
      return "video/mpg";
    case ".webm":
      return "video/webm";
    default:
      return null;
  }
}

bool isDesktop() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}

/// 同步/上传期间保持屏幕常亮，避免息屏后系统限制网络与 CPU。
///
/// iOS 与 Android **统一**走自建 channel（与两端原生实现对称）：
///  - iOS：`AppDelegate.swift` 直接设置 `isIdleTimerDisabled`；
///  - Android：`MainActivity.kt` 设置 `FLAG_KEEP_SCREEN_ON`。
///
/// 不再使用 wakelock_plus —— 其 Dart 端（wakelock_plus_platform_interface
/// 1.6.0）与 Android 端（wakelock_plus 1.1.4）的 pigeon 通道名不一致，
/// 调用必定抛 `channel-error`（Unable to establish connection on channel）。
Future<void> keepScreenOn(bool on) async {
  if (isDesktop()) {
    return;
  }
  try {
    const channel = MethodChannel('com.ZenithLiteAura.app.pho/notifications');
    await channel.invokeMethod('keepScreenOn', {'enable': on});
  } catch (e) {
    // 可恢复异常：失败不应中断同步，按分级体系降为 warning。
    logger.addWarning("keepScreenOn($on) failed: $e");
  }
}

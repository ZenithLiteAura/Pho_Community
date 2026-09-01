import 'dart:io';

import 'package:flutter/services.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:path/path.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

Future<void> keepScreenOn(bool on) async {
  if (isDesktop()) {
    return;
  }
  try {
    if (Platform.isIOS) {
      const channel = MethodChannel('com.example.img_syncer/notifications');
      await channel.invokeMethod('keepScreenOn', {'enable': on});
    } else {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    }
  } catch (e) {
    logger.addLog("keepScreenOn($on) failed: $e");
  }
}

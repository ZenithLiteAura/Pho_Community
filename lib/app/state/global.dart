import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/bridge/run_server.dart';
import 'package:img_syncer/core/sync_timer.dart';
import 'package:img_syncer/app/state/state_model.dart';
import 'package:img_syncer/bridge/storage/storage.dart';
import 'package:img_syncer/bridge/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/app/logger/logger.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io';

import 'package:img_syncer/app/widgets/liquid_glass_toast.dart';

import 'event_bus.dart';

late String httpBaseUrl;
late int grpcPort;
late int httpPort;
bool useRemoteServer = false;
bool isDebug = false;

/// 服务端单请求上传上限（字节），由 Ping 下发，用于上传前预检。
///
/// 0 表示尚未从服务端获取，此时客户端退回 [fallbackMaxUploadSize]。
/// 之所以由服务端下发而不是两端各写一个常量：超限时服务端会直接关闭连接，
/// 客户端只能看到 Broken pipe（收不到 413），必须在上传**之前**就拦下来，
/// 而"上传之前"只有客户端知道自己要传多大，所以上限必须两端一致。
int serverMaxUploadSize = 0;

/// 未取得服务端上限时的兜底值。
/// 应与 server/api/http.go 的 maxUploadSize 保持同量级（当前 8GiB）。
const int fallbackMaxUploadSize = 8 << 30;

Color? seedColor;

class Global {
  static Future init() async {
    assert(() {
      if (!Platform.isIOS) {
        isDebug = true;
      }
      return true;
    }());
    runServer().then((portsStr) async {
      final ports = portsStr.split(",");
      if (ports.length != 2) {
        logger.addError("grpc server start failed");
        return;
      }
      httpBaseUrl = "http://127.0.0.1:${ports[1]}";
      grpcPort = int.parse(ports[0]);
      httpPort = int.parse(ports[1]);
      storage = RemoteStorage("127.0.0.1", int.parse(ports[0]));
      if (useRemoteServer) {
        httpBaseUrl = "http://192.168.100.213:8000";
        storage = RemoteStorage("192.168.100.213", 50051);
      }

      final prefs = await SharedPreferences.getInstance();
      if (isDesktop()) {
        final galleryColumCount = prefs.getInt("galleryColumCount");
        if (galleryColumCount != null) {
          settingModel.setGalleryColumCount(galleryColumCount);
        } else {
          settingModel.setGalleryColumCount(10);
        }
        final uploadParallelCount = prefs.getInt("uploadParallelCount");
        if (uploadParallelCount != null && uploadParallelCount > 0) {
          settingModel.setParallelUploadCount(uploadParallelCount);
        }
        await initDrive();
        return;
      }
      final seedColorValue = prefs.getInt("seed_color");
      if (seedColorValue != null) {
        seedColor = Color(seedColorValue);
      }
      final galleryColumCount = prefs.getInt("galleryColumCount");
      if (galleryColumCount != null) {
        settingModel.setGalleryColumCount(galleryColumCount);
      }
      final uploadParallelCount = prefs.getInt("uploadParallelCount");
      if (uploadParallelCount != null && uploadParallelCount > 0) {
        settingModel.setParallelUploadCount(uploadParallelCount);
      }

      final localFolder = prefs.getString("localFolder");
      if (localFolder != null && localFolder != "") {
        settingModel.setLocalFolder(localFolder);
        if (localFolder != "") {
          eventBus.fire(LocalRefreshEvent(refreshUnSync: false));
        }
      } else {
        await requestPermission(alert: false);
        if (Platform.isIOS) {
          settingModel.setLocalFolder("Recents");
          await prefs.setString("localFolder", "Recents");
          eventBus.fire(LocalRefreshEvent(refreshUnSync: true));
        } else {
          final List<AssetPathEntity> paths =
              await PhotoManager.getAssetPathList(
                  type: RequestType.common, hasAll: true);
          final Map<AssetPathEntity, int> assetCountMap = {
            for (final p in paths) p: await p.assetCountAsync,
          };
          paths.sort((a, b) =>
              (assetCountMap[b] ?? 0).compareTo(assetCountMap[a] ?? 0));
          if (paths.isNotEmpty) {
            settingModel.setLocalFolder(paths[0].name);
            await prefs.setString("localFolder", paths[0].name);
            eventBus.fire(LocalRefreshEvent(refreshUnSync: true));
          }
        }
      }
      final lastRefreshUnsyncTime = prefs.getInt("last_refersh_unsync");
      if (lastRefreshUnsyncTime != null) {
        stateModel.updateLastRefreshUnsyncTime(
            DateTime.fromMillisecondsSinceEpoch(lastRefreshUnsyncTime));
      }
      await assetModel.loadTitleCache();
      await loadUnsynchronizedPhotos();
      await stateModel.loadUploadedHashes();
      await stateModel.loadUploadedNames();
      await stateModel.loadUploadedPaths();
      await initDrive();
      reloadAutoSyncTimer();
    });
  }
}

DateTime? lastAliveTime;
Future<void> checkServer() async {
  if (useRemoteServer) {
    return;
  }
  if (lastAliveTime != null &&
      DateTime.now().difference(lastAliveTime!) < const Duration(seconds: 60)) {
    return;
  }
  try {
    final rsp = await storage.cli.ping(PingRequest());
    // 缓存服务端下发的单请求上传上限，供上传前预检使用。
    final maxSize = rsp.maxUploadSize.toInt();
    if (maxSize > 0) {
      serverMaxUploadSize = maxSize;
    }
    lastAliveTime = DateTime.now();
  } catch (e) {
    logger.addWarning("ping 127.0.0.1:$grpcPort failed: $e");
    logger.addWarning("reboot server");
    final portsStr = await runServer();
    final ports = portsStr.split(",");
    if (ports.length != 2) {
      logger.addError("grpc server start failed");
      return;
    }
    httpBaseUrl = "http://127.0.0.1:${ports[1]}";
    grpcPort = int.parse(ports[0]);
    httpPort = int.parse(ports[1]);
    storage = RemoteStorage("127.0.0.1", int.parse(ports[0]));
    await initDrive();
  }
}

Future<void> initDrive() async {
  final prefs = await SharedPreferences.getInstance();
  var drive = prefs.getString("drive");
  drive ??= "SMB";
  switch (getDrive(drive)) {
    case Drive.smb:
      final addr = prefs.getString("addr");
      final username = prefs.getString("username");
      final password = prefs.getString("password");
      final share = prefs.getString("share");
      final root = prefs.getString("rootPath");
      if (addr != null &&
          username != null &&
          password != null &&
          share != null &&
          root != null) {
        final rsp = await storage.cli.setDriveSMB(SetDriveSMBRequest(
          addr: addr,
          username: username,
          password: password,
          share: share,
          root: root,
        ));
        if (rsp.success) {
          logger.addLog("set drive smb success");
          settingModel.setRemoteStorageSetted(true);
          eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
        } else {
          settingModel.setRemoteStorageSetted(false);
          assetModel.remoteLastError = rsp.message;
        }
      }
      break;
    case Drive.webDav:
      final url = prefs.getString('webdav_url');
      final username = prefs.getString('webdav_username');
      final password = prefs.getString('webdav_password');
      final root = prefs.getString('webdav_root_path');
      final insecure = prefs.getBool('webdav_insecure') ?? true;
      if (url != null && root != null) {
        final primary = SetDriveWebdavRequest(
          addr: url,
          username: username,
          password: password,
          root: root,
          insecure: insecure,
        );
        // 备份 WebDAV（可选）：配置后使用双目标（主目标写失败自动回退备份）
        final backupUrl = prefs.getString('webdav_url2');
        final backupRoot = prefs.getString('webdav_root_path2');
        late SetDriveWebdavResponse rsp;
        if (backupUrl != null && backupUrl.isNotEmpty && backupRoot != null) {
          rsp = await storage.cli.setDriveWebdavDual(SetDriveWebdavDualRequest(
            primary: primary,
            backup: SetDriveWebdavRequest(
              addr: backupUrl,
              username: prefs.getString('webdav_username2'),
              password: prefs.getString('webdav_password2'),
              root: backupRoot,
              insecure: prefs.getBool('webdav_insecure2') ?? true,
            ),
          ));
          logger.addLog("set drive webdav dual (primary + backup)");
        } else {
          rsp = await storage.cli.setDriveWebdav(primary);
          logger.addLog("set drive webdav single");
        }
        if (rsp.success) {
          logger.addLog("set drive webdav success");
          settingModel.setRemoteStorageSetted(true);
          eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
        } else {
          settingModel.setRemoteStorageSetted(false);
          assetModel.remoteLastError = rsp.message;
        }
      }
      break;
    case Drive.nfs:
      final addr = prefs.getString('nfs_url');
      final root = prefs.getString('nfs_root_path');
      if (addr != null && root != null) {
        final rsp = await storage.cli.setDriveNFS(SetDriveNFSRequest(
          addr: addr,
          root: root,
        ));
        if (rsp.success) {
          logger.addLog("set drive nfs success");
          settingModel.setRemoteStorageSetted(true);
          eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
        } else {
          settingModel.setRemoteStorageSetted(false);
          assetModel.remoteLastError = rsp.message;
        }
      }
      break;
  }
}

class SnackBarManager {
  static final SnackBarManager _instance = SnackBarManager._internal();

  factory SnackBarManager() {
    return _instance;
  }

  SnackBarManager._internal();

  static BuildContext? globalContext;

  static void init(BuildContext context) {
    globalContext = context;
  }

  /// 显示一条应用内提示。
  ///
  /// v3.3：改为顶部的液态玻璃提示条（原先贴底的 SnackBar 会遮挡底部悬浮 Dock
  /// 与页面操作区）。签名保持不变，全部调用点无需改动。
  static void showSnackBar(String message) {
    final ctx = globalContext;
    if (ctx == null) return;
    // Overlay 不可用时，LiquidGlassToast 内部会自动降级为原生 SnackBar。
    LiquidGlassToast.show(ctx, message);
  }
}

late AppLocalizations l10n;

void initI18n(BuildContext context) {
  l10n = AppLocalizations.of(context)!;
}

Completer<bool>? requesttingPermission;
BuildContext? requestPermissionContext;
void initRequestPermission(BuildContext context) {
  requestPermissionContext = context;
}

Future<bool> requestPermission({alert = true}) async {
  if (isDesktop()) {
    return true;
  }
  bool result = false;
  if (requesttingPermission != null) {
    result = await requesttingPermission!.future;
    return result;
  }
  requesttingPermission = Completer<bool>();
  //权限申请
  final PermissionState ps = await PhotoManager.requestPermissionExtend();
  if (ps == PermissionState.authorized) {
    result = true;
  } else {
    if (alert) {
      result = false;
      if (requestPermissionContext != null) {
        showDialog(
            context: requestPermissionContext!,
            builder: (BuildContext context) => AlertDialog(
                  title: Text(l10n.needPermision),
                  content: Text(l10n.gotoSystemSetting),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        PhotoManager.openSetting();
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.openSetting),
                    ),
                  ],
                ));
      }
    }
  }
  requesttingPermission?.complete(result);
  requesttingPermission = null;
  return result;
}

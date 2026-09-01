import 'package:flutter/material.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/util.dart';
import 'package:path/path.dart';
import 'package:img_syncer/state_model.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/storage_config_page.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/settings/settings_home.dart';
import 'package:img_syncer/settings/settings_storage.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/widgets/thumbnail_skeleton.dart';
import 'package:img_syncer/sync/background_runner.dart';
import 'package:img_syncer/notifications/local_notifier.dart';

export 'package:img_syncer/sync/background_runner.dart'
    show shouldSyncAsset;

class SyncBody extends StatefulWidget {
  const SyncBody({
    Key? key,
    required this.localFolder,
  }) : super(key: key);

  final String localFolder;

  @override
  SyncBodyState createState() => SyncBodyState();
}

class SyncBodyState extends State<SyncBody> {
  final ScrollController _scrollController = ScrollController();
  final _scrollSubject = PublishSubject<double>();

  @protected
  int pageSize = 20;
  Map<String, String> uploadFailedMap = {};
  bool syncing = false;
  /// v2.2 新增：用户点击停止后立刻置 true，给视觉反馈（FAB 文案「正在停止」+ SnackBar）。
  /// 真正停止由 [runSyncOnce] 完成；之后会同步回调 [syncing] = false。
  bool stopping = false;
  double scrollOffset = 0;
  String _driveName = '';

  @override
  void initState() {
    super.initState();
    // 读取云端存储类型用于概览卡片展示
    SharedPreferences.getInstance().then((prefs) {
      final d = prefs.getString('drive');
      if (d != null && mounted) {
        setState(() {
          _driveName = d;
        });
      }
    });
    _scrollSubject.stream
        .debounceTime(const Duration(milliseconds: 150))
        .listen((scrollPosition) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 1500) {
        // loadMore();
      }
      setState(() {
        scrollOffset = scrollPosition;
      });
    });
    _scrollController.addListener(() {
      _scrollSubject.add(_scrollController.position.pixels);
    });
  }

  @override
  void didUpdateWidget(SyncBody oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
    _scrollSubject.close();
  }

  /// 同步概览卡片：显示本地相册与云端存储状态，点击进入 账户与同步。
  /// 替代原顶部四按钮行（本地文件夹/云端设置/后台同步/设置），
  /// 这些入口已并入设置体系（设置 → 账户与同步）。
  Widget _syncSummaryCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
      ),
      color: colorScheme.surfaceContainerLowest, // surfacePrimary white
      elevation: 0,
      child: ListTile(
        leading: Icon(
          settingModel.isRemoteStorageSetted
              ? Icons.cloud_done_outlined
              : Icons.cloud_off_outlined,
          size: 28,
          color: settingModel.isRemoteStorageSetted
              ? colorScheme.primary
              : colorScheme.primaryContainer,
        ),
        title: Text(
          settingModel.localFolder.isEmpty
              ? l10n.setLocalFirst
              : settingModel.localFolder,
          style: textTheme.bodyLarge?.copyWith(
            fontFamily: AppFonts.body, // Inter 16px
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          settingModel.isRemoteStorageSetted
              ? (_driveName.isEmpty
                  ? l10n.cloudStorage
                  : '${l10n.cloudStorage} · $_driveName')
              : l10n.storageNotSetted,
          style: textTheme.bodyMedium?.copyWith(
            fontFamily: AppFonts.body, // Inter 14px
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsStoragePage()),
          );
        },
      ),
    );
  }

  void syncPhotos() async {
    stateModel.needStopSync = false;
    if (syncing) {
      return;
    }
    setState(() {
      syncing = true;
    });
    uploadFailedMap.clear();
    final Map<String, bool> uploadedIds = {};
    for (final id in stateModel.syncedIDs) {
      uploadedIds[id] = true;
    }
    final all = assetModel.localAssets;
    await keepScreenOn(true);
    final result = await runSyncOnce(
      storage: storageClient,
      assets: all,
      uploadedIds: uploadedIds,
      parallelCount: settingModel.paralleUploadCount,
      callbacks: SyncCallbacks(
        onProgress: (completed, total, failed) {
          if (mounted) {
            stateModel.setSyncProgress(total, completed, failed);
          }
        },
        onAssetFailed: (assetId, error) {
          if (mounted) {
            uploadFailedMap[assetId] = error;
          }
        },
      ),
      shouldStop: () => stateModel.needStopSync,
    );
    await keepScreenOn(false);
    if (mounted) {
      setState(() {
        syncing = false;
        stopping = false;
      });
    }
    stateModel.setSyncProgress(0, 0, 0);
    // 手动同步完成通知（成功数为 0 时静默不发）
    await LocalNotifier.sendSyncCompleteNotification(
      succeeded: result.succeeded,
      failed: result.failed,
    );
  }

  void stopSync() {
    stateModel.needStopSync = true;
    if (!stopping) {
      setState(() {
        stopping = true;
      });
      SnackBarManager.showSnackBar(l10n.stopping);
    }
  }

  Widget columnBuilder(BuildContext context, StateModel model, Widget? child) {
    final Map<String, bool> uploadedIds = {};
    for (final id in stateModel.syncedIDs) {
      uploadedIds[id] = true;
    }
    final all = assetModel.localAssets;
    List<Widget> listChildren = [];
    double currentScrollOffset = 0;
    for (var asset in all) {
      // columnBuilder 为同步函数，使用 localTitle 获取扩展名；
      // 若 localTitle 为空则扩展名为空字符串，filterTypeMap 不会匹配到空串，
      // 等效于跳过类型过滤（与原有行为一致）。
      final ext = asset.localTitle != null
          ? extension(asset.localTitle!)
          : '';
      if (!shouldSyncAsset(asset, asset.local!.id, uploadedIds, ext)) {
        continue;
      }
      final totalHeight = MediaQuery.of(context).size.height;
      bool needLoadThumbnail = false;
      if (currentScrollOffset > scrollOffset - (2 * totalHeight) &&
          currentScrollOffset < scrollOffset + (3 * totalHeight)) {
        needLoadThumbnail = true;
        if (!asset.loadThumbnailFinished()) {
          asset.thumbnailDataAsync().then((value) {
            if (mounted) setState(() {});
          });
        }
        if (!asset.hasGotTitle()) {
          asset.getLocalFile().then((value) {
            if (mounted) setState(() {});
          });
        }
      }
      Widget child = ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card), // squircle corners
            child: needLoadThumbnail && asset.loadThumbnailFinished()
                ? Image(image: asset.thumbnailProvider(), fit: BoxFit.cover)
                : ThumbnailSkeleton(width: 60, height: 60),
          ),
        ),
        title: needLoadThumbnail
            ? FutureBuilder(
                future: asset.name(),
                builder: (context, name) => Text(
                  name.data ?? "",
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: AppFonts.body, // Inter
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            : null,
        subtitle: needLoadThumbnail
            ? Consumer<StateModel>(
                builder: (context, stateModel, child) {
                  final percent = stateModel.getUploadPercent(asset.local!.id);
                  if (percent > 0) {
                    return Container(
                      padding: const EdgeInsets.fromLTRB(0, 0, 10, 0),
                      child: LinearProgressIndicator(
                        value: percent,
                        color: AppColors.primary, // Fluid Horizon primary
                        backgroundColor: AppColors.surfaceContainerHighest,
                      ),
                    );
                  }
                  if (!stateModel.syncedIDs.contains(asset.local!.id)) {
                    if (uploadFailedMap.containsKey(asset.local!.id)) {
                      return Text(
                        "${l10n.uploadFailed}: ${uploadFailedMap[asset.local!.id]}",
                        style: TextStyle(
                            color: AppColors.error),
                      );
                    }
                    return Text(l10n.notUploaded,
                        style: TextStyle(
                            color: AppColors.textSecondary));
                  }
                  return Text(
                    l10n.uploaded,
                    style: TextStyle(
                        color: AppColors.accentSuccess),
                  );
                },
              )
            : Container(),
      );
      listChildren.add(child);
      currentScrollOffset += 72; // ListTile's height
    }
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.cloudSync,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: AppFonts.title, // Plus Jakarta Sans
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.fromLTRB(0, 0, AppSpacing.xs, AppSpacing.xs),
            alignment: Alignment.bottomRight,
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
            child: Text(
              syncing
                  ? "${stateModel.syncCompleted}/${stateModel.syncTotal} (${(stateModel.syncPercent * 100).toInt()}%)"
                  : "${listChildren.length} ${l10n.notSync}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "refresh",
            tooltip: l10n.refreshUnsynchronizedPhotos,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.buttonFull), // pill shape
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            onPressed: () => syncing ||
                    model.refreshingUnsynchronized ||
                    model.isDownloading() ||
                    model.isUploading()
                ? null
                : refreshUnsynchronized(),
            child: model.refreshingUnsynchronized
                ? CircularProgress()
                : const Icon(Icons.refresh),
          ),
          Container(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: FloatingActionButton.extended(
                heroTag: "sync",
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.buttonFull), // pill shape
                ),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                onPressed: stopping
                    ? null
                    : () {
                        if (!settingModel.isRemoteStorageSetted) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StorageConfigPage(),
                              ));
                          return;
                        }
                        if (syncing ||
                            model.refreshingUnsynchronized ||
                            model.isDownloading() ||
                            model.isUploading()) {
                          stopSync();
                        } else {
                          syncPhotos();
                        }
                      },
                icon: syncing ? CircularProgress() : const Icon(Icons.sync),
                label: Text(
                  stopping
                      ? l10n.stopping
                      : syncing
                          ? l10n.stop
                          : l10n.sync,
                )),
          ),
        ],
      ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _syncSummaryCard(context),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.sm, 0),
                child: Text(
                  l10n.unsynchronizedPhotos,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Flexible(
                child: Divider(
                  height: 10,
                  thickness: 1,
                  indent: 0,
                  endIndent: AppSpacing.md,
                ),
              ),
            ],
          ),
          if (!settingModel.isRemoteStorageSetted)
            Container(
              height: 250,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Center(
                heightFactor: 10,
                child: Text(l10n.setRemoteStroage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
          model.refreshingUnsynchronized && listChildren.isEmpty
              ? Container(
                  height: 250,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Center(
                    heightFactor: 10,
                    child: Text(l10n.refreshingPleaseWait,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                )
              : Flexible(
                  child: ListView(
                  controller: _scrollController,
                  children: listChildren,
                )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StateModel>(
      builder: columnBuilder,
    );
  }

  Widget CircularProgress() {
    final cs = Theme.of(this.context).colorScheme;
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
        strokeWidth: 2,
      ),
    );
  }

  Future<void> refreshUnsynchronized() async {
    if (!settingModel.isRemoteStorageSetted) {
      stateModel.setSyncedPhotos([]);
      return;
    }
    uploadFailedMap.clear();
    await refreshUnsynchronizedPhotos();
  }
}

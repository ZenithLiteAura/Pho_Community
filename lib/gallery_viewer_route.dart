import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/util.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:url_launcher/url_launcher.dart';
import 'event_bus.dart';
import 'package:extended_image/extended_image.dart';
import 'package:img_syncer/video_route.dart';
import 'package:img_syncer/global.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

class GalleryViewerRoute extends StatefulWidget {
  const GalleryViewerRoute({
    Key? key,
    required this.useLocal,
    required this.originIndex,
  }) : super(key: key);
  final bool useLocal;
  final int originIndex;

  @override
  GalleryViewerRouteState createState() => GalleryViewerRouteState();
}

class GalleryViewerRouteState extends State<GalleryViewerRoute>
    with TickerProviderStateMixin {
  // late final PageController _pageController;
  late final ExtendedPageController _pageController;
  late AnimationController _animationController;
  bool showLivePhotoVideo = false;
  bool showLoading = false;
  VideoPlayerController? _videoController;
  late List<Asset> all;
  late int currentIndex;
  bool showAppBar = true;
  bool poped = false;
  VoidCallback? _doubleTapListener;
  late final AssetModel _assetModel;

  void _onAssetModelChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAnimationTick() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _assetModel = context.read<AssetModel>();
    currentIndex = widget.originIndex;
    _pageController = ExtendedPageController(
      initialPage: widget.originIndex,
      keepPage: true,
    );
    all = widget.useLocal ? _assetModel.localAssets : _assetModel.remoteAssets;
    // 延迟加载全分辨率数据，避免 Hero 动画期间 HTTP 下载抢占主 isolate 事件循环
    // 延迟 400ms 确保 300ms 的 FadeTransition 动画完成后再启动下载
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        all[currentIndex].readInfoFromData();
      }
    });
    _assetModel.addListener(_onAssetModelChange);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // 你可以调整动画时间
    );
    _animationController.addListener(_onAnimationTick);
  }

  @override
  void didUpdateWidget(covariant GalleryViewerRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _assetModel.removeListener(_onAssetModelChange);
    _animationController.removeListener(_onAnimationTick);
    if (_doubleTapListener != null) {
      _animationController.removeListener(_doubleTapListener!);
      _doubleTapListener = null;
    }
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _isShowingImageInfo = false;
  void showImageInfo(BuildContext context) {
    final currentAsset = all[currentIndex];
    if (!currentAsset.isInfoReady()) {
      return;
    }
    if (_isShowingImageInfo) {
      return;
    }
    _isShowingImageInfo = true;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.extraLarge)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        List<Widget> columns = [];
        columns.add(
          // 抓手
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
            height: 4.0,
            width: 40.0,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
        );
        if (currentAsset.date != null) {
          columns.add(ListTile(
              leading: SizedBox(
                width: 40, // 设置宽度
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_today_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: Text(l10n.date, style: textTheme.titleMedium),
              subtitle: Text(
                currentAsset.date!,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              )));
        }
        if (currentAsset.make != null && currentAsset.model != null) {
          List<String> children = [
            if (currentAsset.fNumber != null) "f/${currentAsset.fNumber}",
            if (currentAsset.exposureTime != null) currentAsset.exposureTime!,
            if (currentAsset.focalLength != null)
              "${currentAsset.focalLength}mm",
            if (currentAsset.iSO != null) "ISO${currentAsset.iSO}",
          ];
          columns.add(
            ListTile(
              leading: SizedBox(
                width: 40, // 设置宽度
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.camera_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: Text("${currentAsset.make} ${currentAsset.model}",
                  style: textTheme.titleMedium),
              subtitle: Text(
                children.join("  \u2022  "),
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        columns.add(ListTile(
          leading: SizedBox(
            width: 40, // 设置宽度
            child: Align(
              alignment: Alignment.center,
              child: Icon(
                currentAsset.isVideo()
                    ? Icons.movie
                    : Icons.photo_size_select_actual_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: FutureBuilder(
              future: all[currentIndex].name(),
              builder: (context, snapshot) =>
                  Text(snapshot.data ?? "", style: textTheme.titleMedium),
            ),
          ),
          subtitle: currentAsset.isVideo()
              ? null
              : RichText(
                  text: TextSpan(
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                    children: [
                      TextSpan(
                        text: currentAsset.imageWidth != null &&
                                currentAsset.imageHeight != null
                            ? "${(currentAsset.imageWidth! * currentAsset.imageHeight! / 1024 / 1024).floor()} MP"
                            : null,
                      ),
                      TextSpan(
                          text: currentAsset.imageWidth != null
                              ? "  \u2022  ${currentAsset.imageWidth!}x${currentAsset.imageHeight!}"
                              : null),
                    ],
                  ),
                ),
        ));

        columns.add(ListTile(
          leading: SizedBox(
            width: 40, // 设置宽度
            child: Align(
              alignment: Alignment.center,
              child: Icon(
                currentAsset.hasLocal
                    ? Icons.phone_android
                    : Icons.cloud_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          title: currentAsset.isLocal()
              ? Text(l10n.localView, style: textTheme.titleMedium)
              : Text(l10n.cloudView, style: textTheme.titleMedium),
          subtitle: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: FutureBuilder(
              future: Future.wait([
                currentAsset.path(),
                currentAsset.size(),
              ]),
              builder: (context, snapshot) => snapshot.data == null
                  ? Container()
                  : RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                        children: [
                          TextSpan(
                              text:
                                  "${(snapshot.data![1] as double).toStringAsFixed(1)} MB"),
                          if (currentAsset.hasRemote || Platform.isAndroid) ...[
                            const TextSpan(text: "  \u2022  "),
                            TextSpan(text: snapshot.data![0] as String? ?? ""),
                          ]
                        ],
                      ),
                    ),
            ),
          ),
        ));
        if (Platform.isIOS) columns.add(const SizedBox(height: 20));
        return IntrinsicHeight(
          child: Column(
            children: columns,
          ),
        );
      },
    ).then((value) => _isShowingImageInfo = false);
  }

  void deleteCurrent(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.deleteThisPhoto),
        content: Text(l10n.cantBeUndone),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              all[currentIndex].delete().then((value) async {
                try {
                  if (all[currentIndex].hasLocal) {
                    _assetModel.removeLocalAsset(all[currentIndex]);
                  } else {
                    _assetModel.removeRemoteAsset(all[currentIndex]);
                    final id = await findLocalIDByAsset(all[currentIndex]);
                    if (id != null) {
                      stateModel.removeSyncedPhotos([id]);
                      stateModel.saveSyncedIDs();
                    }
                  }
                } catch (e) {
                  SnackBarManager.showSnackBar(e.toString());
                }
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              });
            },
            child: Text(l10n.yes),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void download(Asset asset) async {
    if (asset.isLocal()) {
      return;
    }
    await keepScreenOn(true);
    final name = await asset.originName();
    try {
      Uint8List data;
      if (!asset.isVideo()) {
        data = await asset.imageDataAsync(reportProgress: true);
      } else {
        data = await asset.remote!.imageData();
      }
      if (Platform.isAndroid) {
        String absPath = '${settingModel.localFolderAbsPath}/$name';
        final file = File(absPath);
        if (file.existsSync()) {
          throw Exception("$name already exists, skip download.");
        }
        await file.writeAsBytes(data);
        await file.setLastModified(asset.dateCreated());
        await scanFile(absPath);
        SnackBarManager.showSnackBar("${l10n.download} $name ${l10n.success}");
      } else if (Platform.isIOS) {
        var appDocDir = await getTemporaryDirectory();
        String savePath = "${appDocDir.path}/$name";
        final file = File(savePath);
        // if (file.existsSync()) {
        //   throw Exception("$name already exists, skip download.");
        // }
        await file.writeAsBytes(data);
        await file.setLastModified(asset.dateCreated());
        if (asset.isVideo()) {
          await Gal.putVideo(savePath);
        } else {
          await Gal.putImage(savePath);
        }
        SnackBarManager.showSnackBar(
            "${l10n.download} $name ${l10n.success}\n${l10n.browseInRecents}");
      } else if (isDesktop()) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Please select an output file:',
          fileName: name,
        );
        if (outputFile == null) {
          return;
        }
        final file = File(outputFile);
        await file.writeAsBytes(data);
        SnackBarManager.showSnackBar("${l10n.download} $name ${l10n.success}");
      }
      eventBus.fire(LocalRefreshEvent(refreshUnSync: false));
    } catch (e) {
      SnackBarManager.showSnackBar(e.toString());
    } finally {
      keepScreenOn(false);
    }
  }

  void upload(Asset asset) async {
    if (!asset.isLocal()) {
      return;
    }

    if (!settingModel.isRemoteStorageSetted) {
      SnackBarManager.showSnackBar(
          "Remote storage is not setted,please set it first");
      return;
    }
    final entity = asset.local;
    if (entity == null) {
      SnackBarManager.showSnackBar("Asset local is null, unable to upload");
      return;
    }
    await keepScreenOn(true);
    try {
      await storage.uploadAssetEntity(entity);
      if (mounted) {
        SnackBarManager.showSnackBar(
            "${l10n.upload} ${await asset.name()} ${l10n.success}");
      }
      eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
      // syncedIDs 已由 uploadAssetEntity 内部的 finishUpload 处理，不需要重复添加
    } catch (e) {
      logger.addLog(e.toString());
      SnackBarManager.showSnackBar(e.toString());
    } finally {
      keepScreenOn(false);
    }
  }

  Widget livePhotoVideoPlayer(Asset asset) {
    if (_videoController == null) {
      return Container();
    }
    late double aspectRatio;
    if (asset.imageWidth == null ||
        asset.imageHeight == null ||
        asset.imageWidth! <= 0 ||
        asset.imageHeight! <= 0) {
      aspectRatio = _videoController!.value.aspectRatio;
    } else {
      aspectRatio = asset.imageWidth! / asset.imageHeight!;
    }
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio, // 指定你想要的宽高比
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: colorScheme.scrim.withOpacity(0.25),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                if (all[currentIndex].isLivePhoto())
                  IconButton(
                    icon: SizedBox(
                      height: 23,
                      width: 23,
                      child: Image.asset("assets/icon/live_photos.png"),
                    ),
                    onPressed: null,
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => deleteCurrent(context),
                ),
                if (!isDesktop())
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () async {
                      try {
                        final tempFilePath =
                            await all[currentIndex].downloadToTmpFilePath();
                        Share.shareXFiles([
                          XFile(tempFilePath,
                              name: await all[currentIndex].originName(),
                              mimeType: await all[currentIndex].mimeType())
                        ]);
                      } catch (e) {
                        SnackBarManager.showSnackBar("Share failed: $e");
                      }
                    },
                  ),
                if (!all[currentIndex].isLocal())
                  Consumer<StateModel>(builder: (context, model, child) {
                    return IconButton(
                      icon: const Icon(Icons.cloud_download_outlined),
                      onPressed: () =>
                          model.isDownloading() || model.isUploading()
                              ? null
                              : download(all[currentIndex]),
                    );
                  }),
                if (all[currentIndex].isLocal())
                  Consumer<StateModel>(builder: (context, stateModel, child) {
                    final asset = all[currentIndex];
                    final isSynced = asset.local != null &&
                        stateModel.syncedIDs.isNotEmpty &&
                        stateModel.syncedIDs.contains(asset.local!.id);
                    final isBusy =
                        stateModel.isDownloading() || stateModel.isUploading();
                    return IconButton(
                      icon: isSynced
                          ? const Icon(Icons.cloud_done_outlined,
                              color: Color.fromARGB(255, 90, 252, 101))
                          : const Icon(Icons.cloud_upload_outlined),
                      // 已上传或传输中时禁用按钮
                      onPressed:
                          isSynced || isBusy ? null : () => upload(asset),
                    );
                  }),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    all[currentIndex].imageDataAsync().then(
                          (value) => showImageInfo(context),
                        );
                  },
                ),
              ],
            )
          : null,
      body: Hero(
        tag:
            "asset_${widget.useLocal ? "local" : "remote"}_${all[currentIndex].hasLocal ? all[currentIndex].local!.id : all[currentIndex].remote!.path}",
        flightShuttleBuilder: (BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext) {
          // 自定义过渡动画小部件
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              return Opacity(
                opacity: animation.value,
                child: ExtendedImage(
                  image: all[currentIndex].thumbnailProvider(),
                  fit: BoxFit.contain,
                ),
              );
            },
          );
        },
        child: Container(
          constraints: BoxConstraints.expand(
            height: MediaQuery.of(context).size.height,
          ),
          child: Stack(
            children: [
              ExtendedImageGesturePageView.builder(
                itemCount: all.length,
                controller: _pageController,
                onPageChanged: (int index) {
                  setState(() {
                    currentIndex = index;
                  });
                  all[index].readInfoFromData().then((value) {
                    if (index + 1 >= 0 && index + 1 < all.length) {
                      all[index + 1].thumbnailDataAsync();
                      all[index + 1].imageDataAsync();
                    }
                    if (index - 1 >= 0 && index - 1 < all.length) {
                      all[index - 1].thumbnailDataAsync();
                      all[index - 1].imageDataAsync();
                    }
                  });
                },
                itemBuilder: (BuildContext context, int index) {
                  return Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: [
                      ExtendedImage(
                        image: all[index],
                        fit: BoxFit.contain,
                        mode: ExtendedImageMode.gesture,
                        initGestureConfigHandler: (state) {
                          return GestureConfig(
                            minScale: 1.0,
                            maxScale: 3.0,
                            inPageView: true,
                            gestureDetailsIsChanged: (details) {
                              if (details == null) {
                                return;
                              }
                              // 如果是下拉手势则弹出ImageInfo
                              if (details.totalScale == 1.0 &&
                                  details.offset!.dy < -100) {
                                showImageInfo(context);
                              }
                              // 如果是上拉手势则返回
                              if (details.totalScale == 1.0 &&
                                  details.offset!.dy > 100) {
                                if (!poped) {
                                  poped = true;
                                  Navigator.pop(context);
                                }
                              }
                            },
                          );
                        },
                        loadStateChanged: (ExtendedImageState state) {
                          switch (state.extendedImageLoadState) {
                            case LoadState.loading:
                              return ExtendedImage(
                                image: all[index].thumbnailProvider(),
                                fit: BoxFit.contain,
                              );
                            case LoadState.completed:
                              return null; // Use the high-resolution image.
                            case LoadState.failed:
                              all[index].name().then((n) {
                                if (n.toLowerCase().contains(".heic") ||
                                    n.toLowerCase().contains(".hevc")) {
                                  if (Platform.isWindows) {
                                    showDialog(
                                        context: SnackBarManager.globalContext!,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text(l10n.hevcExtention),
                                            content:
                                                Text(l10n.installHEVCExtention),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: Text(l10n.cancel),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  Navigator.of(context).pop();
                                                  final Uri ExtUrl = Uri.parse(
                                                      'https://apps.microsoft.com/detail/9NMZLZ57R3T7');
                                                  launchUrl(ExtUrl,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                },
                                                child: Text(l10n.openMSStore),
                                              ),
                                            ],
                                          );
                                        });
                                  }
                                }
                              });
                              return null;
                            default:
                              return null;
                          }
                        },
                        onDoubleTap: (ExtendedImageGestureState state) {
                          if (state.gestureDetails != null &&
                              state.gestureDetails!.totalScale != null) {
                            double begin = state.gestureDetails!.totalScale!;
                            double end =
                                state.gestureDetails!.totalScale! >= 2.0
                                    ? 1.0
                                    : 2.0;
                            _animationController.reset();
                            if (_doubleTapListener != null) {
                              _animationController
                                  .removeListener(_doubleTapListener!);
                            }
                            _doubleTapListener = () {
                              double animationScale =
                                  (end - begin) * _animationController.value;
                              state.handleDoubleTap(
                                  scale: begin + animationScale);
                            };
                            _animationController
                                .addListener(_doubleTapListener!);
                            _animationController.forward();
                          }
                        },
                      ),
                      if (all[index].isVideo())
                        const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white,
                          size: 60,
                        ),
                      GestureDetector(
                        onTap: () async {
                          if (all[index].isVideo()) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => VideoRoute(
                                  asset: all[index],
                                ),
                              ),
                            );
                          } else {
                            setState(() {
                              showAppBar = !showAppBar;
                            });
                          }
                        },
                        onLongPress: () async {
                          if (!all[index].isLivePhoto()) {
                            return;
                          }
                          _videoController =
                              await all[index].getLivePhotoVideoController();
                          if (_videoController == null) {
                            return;
                          }
                          try {
                            await _videoController!.initialize();
                            HapticFeedback.lightImpact();
                            await _videoController!.play();
                            setState(() {
                              showLivePhotoVideo = true;
                            });
                          } catch (e) {
                            SnackBarManager.showSnackBar(
                                "Play live photo failed: $e");
                          }
                        },
                        onLongPressEnd: (details) {
                          setState(() {
                            showLivePhotoVideo = false;
                          });
                          if (_videoController != null) {
                            _videoController!.pause();
                            _videoController!.dispose();
                            _videoController = null;
                          }
                        },
                      ),
                      Positioned(
                          top: MediaQuery.of(context).padding.top,
                          left: 0,
                          width: MediaQuery.of(context).size.width,
                          child: ValueListenableBuilder<double>(
                            valueListenable: all[index].imageLoadProgress,
                            builder: (context, progress, child) {
                              if (progress > 0 && progress < 1) {
                                return LinearProgressIndicator(
                                  value: progress,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.7),
                                  backgroundColor: Colors.transparent,
                                );
                              }
                              return Container();
                            },
                          )),
                      Center(
                        child: Consumer<StateModel>(
                          builder: (context, model, child) {
                            double percent = 0;
                            if (all[currentIndex].isLocal()) {
                              percent = model.getUploadPercent(
                                  all[currentIndex].local!.id);
                            }
                            if (percent > 0) {
                              return SizedBox(
                                width: 45,
                                height: 45,
                                child: CircularProgressIndicator(
                                  value: percent,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.transparent,
                                ),
                              );
                            }
                            return Container();
                          },
                        ),
                      ),
                      if (showLoading)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                      if (showLivePhotoVideo && _videoController != null)
                        livePhotoVideoPlayer(all[currentIndex]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

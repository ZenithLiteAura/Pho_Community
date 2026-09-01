import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/widgets/thumbnail_skeleton.dart';
import 'package:flutter/services.dart';

class ChooseAlbumRoute extends StatefulWidget {
  const ChooseAlbumRoute({Key? key}) : super(key: key);
  @override
  ChooseAlbumRouteState createState() => ChooseAlbumRouteState();
}

class ChooseAlbumRouteState extends State<ChooseAlbumRoute> {
  List<AssetPathEntity> albums = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getAlbums().then((value) {
        setState(() {
          albums = value;
        });
      });
    });
  }

  Future<List<AssetPathEntity>> getAlbums() async {
    final re = await requestPermission();
    if (!re) return [];
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.common, hasAll: true);
    // sort by asset count by assetCountAsync
    // 使用Future.wait来获取所有异步值并保存到Map中
    final Map<AssetPathEntity, int> assetCountMap = {};
    await Future.wait(paths.map((path) async {
      int assetCount = await path.assetCountAsync;
      assetCountMap[path] = assetCount;
    }));

    // 使用sort方法对paths进行排序
    paths.sort((a, b) {
      int countA = assetCountMap[a] ?? 0;
      int countB = assetCountMap[b] ?? 0;
      return countB.compareTo(countA); // 从大到小排序
    });
    return paths;
  }

  Future<Uint8List?> getFirstPhotoThumbnail(AssetPathEntity path) async {
    try {
      final List<AssetEntity> entities =
          await path.getAssetListPaged(page: 0, size: 1);
      if (entities.isNotEmpty) {
        final entity = entities[0];
        final data = await entity
            .thumbnailDataWithSize(const ThumbnailSize.square(400), quality: 90);
        return data;
      }
    } catch (e) {
      print("[ChooseAlbum] getFirstPhotoThumbnail 失败: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    for (var path in albums) {
      children.add(
        FutureBuilder(
          future: getFirstPhotoThumbnail(path),
          builder: (context, snapshot) {
            return AlbumCard(
              path: path,
              thumbnail: snapshot.data,
            );
          },
        ),
      );
    }
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          iconTheme: Theme.of(context).iconTheme,
          elevation: 0,
          title: Text(l10n.chooseAlbum,
              style: Theme.of(context).textTheme.titleLarge),
        ),
        body: CustomScrollView(
          primary: false,
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              sliver: SliverGrid.count(
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                children: children,
              ),
            ),
          ],
        ));
  }
}

class AlbumCard extends StatelessWidget {
  final AssetPathEntity path;
  final Uint8List? thumbnail;
  const AlbumCard({
    Key? key,
    required this.path,
    required this.thumbnail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight - 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.extraSmall),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: thumbnail != null
                      ? Image.memory(thumbnail!, fit: BoxFit.cover)
                      : ThumbnailSkeleton()),
              Container(
                  alignment: Alignment.centerLeft,
                  height: 40,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: Text(
                            path.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge),
                      ),
                    ],
                  )),
              Container(
                alignment: Alignment.centerRight,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FutureBuilder(
                      future: path.assetCountAsync,
                      builder: (context, snapshot) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withAlpha(128),
                          borderRadius: BorderRadius.circular(AppRadius.buttonFull),
                        ),
                        child: Text(
                          "${(snapshot.data ?? 0)}",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs),
                      ),
                      onPressed: () {
                        stateModel.updateLastRefreshUnsyncTime(null);
                        settingModel.setLocalFolder(path.name);
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setString("localFolder", path.name);
                        });
                        eventBus.fire(LocalRefreshEvent(refreshUnSync: true));
                        Navigator.pop(context);
                      },
                      child: Text(l10n.choose),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

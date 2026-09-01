import 'package:flutter/material.dart';

import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/widgets/thumbnail_skeleton.dart';

/// 独立 StatefulWidget：单张缩略图 cell。
///
/// v3.1 性能优化：
/// - 自己管理缩略图加载，setState 只碰这一个 cell
/// - 不会触发父级 GalleryBody 的全页重建
/// - 内置 RepaintBoundary 隔离重绘
class GalleryThumbnailCell extends StatefulWidget {
  const GalleryThumbnailCell({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.enablePreload,
  });

  final Asset asset;
  final double width;
  final double height;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool enablePreload;

  @override
  State<GalleryThumbnailCell> createState() => _GalleryThumbnailCellState();
}

class _GalleryThumbnailCellState extends State<GalleryThumbnailCell> {
  bool _thumbnailReady = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  @override
  void didUpdateWidget(covariant GalleryThumbnailCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _thumbnailReady = widget.asset.loadThumbnailFinished();
      _checkAndLoad();
    }
  }

  void _checkAndLoad() {
    if (widget.asset.loadThumbnailFinished()) {
      _thumbnailReady = true;
      return;
    }
    if (!widget.enablePreload) return;
    widget.asset.thumbnailDataAsync().then((_) {
      if (mounted) {
        setState(() {
          _thumbnailReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            color: colorScheme.surfaceContainerHighest,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_thumbnailReady)
                Image(
                  image: widget.asset.thumbnailProvider(),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              else
                const ThumbnailSkeleton(),
              if (_thumbnailReady && widget.asset.isVideo())
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(AppRadius.extraSmall),
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 14, color: Colors.white),
                  ),
                ),
              if (widget.isSelected)
                Container(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  child: const Center(
                    child: Icon(Icons.check_circle,
                        color: Colors.white, size: 28),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
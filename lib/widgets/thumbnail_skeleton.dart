import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:shimmer/shimmer.dart';

/// 缩略图加载时的骨架屏 Widget。
///
/// 使用 shimmer 效果展示占位区域，可自定义宽高；当宽高为 null 时填满父容器。
class ThumbnailSkeleton extends StatelessWidget {
  final double? width;
  final double? height;

  const ThumbnailSkeleton({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = Theme.of(context).colorScheme.surfaceContainerLow;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1000),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(AppRadius.extraSmall),
        ),
      ),
    );
  }
}

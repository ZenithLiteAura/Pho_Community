import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:img_syncer/app/theme/design_tokens.dart';
import 'jelly_overlay.dart';
import 'miuix_glass_surface.dart';
import 'motion_controller.dart';
import 'motion_origin.dart';

/// 统一浮层入口：触点展开 + 液态玻璃 + 凝光 + 果冻拖拽。
///
/// 取代裸用 `showDialog` / `showGeneralDialog` / `showModalBottomSheet`，
/// 让全应用弹层共享同一套动效语言。动效强度由 [motionController] 控制，
/// 用户可在「设置 → 外观与主题 → 动效」里切 关 / 简 / 全。
///
/// 展开原点取自 [MotionOrigin.last]（app 根部有全局 `Listener` 记录），
/// 因此**调用点无需传坐标**；取不到时退化为居中展开。
Future<T?> showMiuixOverlay<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  bool useRootNavigator = true,
  bool dragToDismiss = true,
  bool showGrip = false,
  bool wrapInGlass = true,
  bool bottomAligned = false,
  bool pointerDrag = true,
  double? maxWidth,
  Color? barrierColor,
  RouteSettings? routeSettings,
}) {
  final level = motionController.level;
  final cs = Theme.of(context).colorScheme;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? cs.scrim.withValues(alpha: 0.32),
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration: motionController.enterDuration,
    // 面板自身的展开由 MiuixOverlayHost 逐帧驱动（AnimatedBuilder），
    // 这里不再叠加路由自带的淡入，避免双重动画把形变冲淡。
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        child,
    pageBuilder: (ctx, _, __) => MiuixOverlayHost<T>(
      origin: MotionOrigin.last,
      level: level,
      builder: builder,
      dragToDismiss: dragToDismiss,
      showGrip: showGrip,
      wrapInGlass: wrapInGlass,
      bottomAligned: bottomAligned,
      pointerDrag: pointerDrag,
      maxWidth: maxWidth,
      enterDuration: motionController.enterDuration,
      onRequestDismiss: () => Navigator.of(ctx).maybePop(),
    ),
  );
}

/// 与 `showDialog` 同签名的替代：把既有 `showDialog(...)` 调用点直接换成它，
/// 即可获得统一的展开/玻璃/凝光/果冻动效。
Future<T?> showMiuixDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  bool useRootNavigator = true,
  // 默认关闭拖拽：这类弹层不需要「拖着关」，裸指针拖拽也容易和内容手势打架
  bool dragToDismiss = false,
  bool showGrip = false,
  bool wrapInGlass = true,
  bool bottomAligned = false,
  bool pointerDrag = false,
  double? maxWidth,
  RouteSettings? routeSettings,
}) {
  return showMiuixOverlay<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    dragToDismiss: dragToDismiss,
    showGrip: showGrip,
    wrapInGlass: wrapInGlass,
    bottomAligned: bottomAligned,
    pointerDrag: pointerDrag,
    maxWidth: maxWidth,
    routeSettings: routeSettings,
  );
}

/// 浮层宿主：负责触点展开动画、玻璃表面、果冻拖拽。
class MiuixOverlayHost<T> extends StatefulWidget {
  const MiuixOverlayHost({
    super.key,
    required this.origin,
    required this.level,
    required this.builder,
    required this.onRequestDismiss,
    required this.enterDuration,
    this.dragToDismiss = true,
    this.showGrip = false,
    this.wrapInGlass = true,
    this.bottomAligned = false,
    this.pointerDrag = true,
    this.maxWidth,
  });

  final Offset? origin;
  final MotionLevel level;
  final WidgetBuilder builder;
  final VoidCallback onRequestDismiss;
  final Duration enterDuration;
  final bool dragToDismiss;
  final bool showGrip;
  final bool wrapInGlass;

  /// 是否底部对齐（底部弹层样式：贴底、通栏、仅上方圆角）。
  final bool bottomAligned;

  /// 是否用裸指针事件（`Listener`）跟踪拖拽。
  ///
  /// 裸指针**不参与手势竞技场**，因此无论落点在哪个子组件上都能拖动，
  /// 不会被可滚动列表之类抢走 —— 这是「任意位置都能拖」的保证。
  /// 内容需要滚动时应传 false（否则滚动会被拖拽顶掉），此时靠顶部抓手拖。
  final bool pointerDrag;
  final double? maxWidth;

  @override
  State<MiuixOverlayHost<T>> createState() => MiuixOverlayHostState<T>();
}

class MiuixOverlayHostState<T> extends State<MiuixOverlayHost<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: widget.enterDuration,
  );

  /// 展开动画结束后才启用背景模糊 —— 动画期间逐帧重算模糊代价高。
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _enter.forward().whenComplete(() {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isBottom = widget.bottomAligned;

    // 缩放参考点：底部对齐时是「底边中点」，否则是面板中心（居中）。
    // 两者都无需测量面板尺寸即可算出。
    final anchor = isBottom
        ? Offset(size.width / 2, size.height)
        : Offset(size.width / 2, size.height / 2);
    final origin = widget.origin;
    final delta = origin == null ? Offset.zero : origin - anchor;

    final width = isBottom
        ? size.width
        : (widget.maxWidth ??
            math.min(size.width - AppSpacing.lg * 2, 420.0));

    final corners = isBottom
        ? const BorderRadius.vertical(
            top: Radius.circular(AppRadius.extraLarge),
          )
        : BorderRadius.circular(AppRadius.extraLarge);

    Widget content = widget.builder(context);

    // 玻璃盒本身就是唯一的面板。AlertDialog（以及任何 Material 对话框）自带一层
    // 不透明表面 + elevation + insetPadding，套在玻璃盒里就会看到「外面一层模糊框、
    // 里面一层更小的实心框」两个大小不一的框 —— 这里把它让掉：
    // 背景透明、无阴影、无内边距，只保留 AlertDialog 自己的内容排版。
    if (widget.wrapInGlass) {
      final base = Theme.of(context);
      content = Theme(
        data: base.copyWith(
          dialogTheme: base.dialogTheme.copyWith(
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        child: content,
      );
    }

    if (widget.showGrip) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MiuixOverlayGrip(),
          content,
        ],
      );
    }

    Widget panel = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: size.height * 0.9,
      ),
      child: widget.wrapInGlass
          ? MiuixGlassSurface(
              enableBlur: _settled,
              corners: corners,
              // 浮层不再画「凝光跟随手指」：观感更干净，也少一层随手指重绘
              enableBloom: false,
              child: content,
            )
          : content,
    );

    panel = JellyDragContainer(
      dragToDismiss:
          widget.dragToDismiss && motionController.dragToDismissEnabled,
      pointerDrag: widget.pointerDrag,
      onDismiss: widget.onRequestDismiss,
      child: panel,
    );

    // 关键：必须用 AnimatedBuilder 让面板在展开动画的**每一帧**都重建形变。
    // 之前只在动画结束后 setState 一次，导致整段动画期间面板都停在最小尺度
    // （几乎不可见），动画一结束才突然以完整尺寸出现 —— 表现为"没有动画、很生硬"。
    // panel 以 child 传入，不参与逐帧重建，只有外层 Transform 重建。
    final animated = AnimatedBuilder(
      animation: _enter,
      child: panel,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        if (!motionController.morphEnabled || origin == null) {
          return Opacity(opacity: t, child: child);
        }
        // 以触点为原点的缩放：p → 原点 + (p - 原点) * s
        // 等价于「先按参考点缩放 s，再平移 delta * (1 - s)」。
        final s = 0.04 + 0.96 * t;
        return Opacity(
          opacity: (t * 1.8).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: delta * (1 - s),
            child: Transform.scale(
              scale: s,
              alignment:
                  isBottom ? Alignment.bottomCenter : Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );

    if (isBottom) {
      return Align(alignment: Alignment.bottomCenter, child: animated);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.lg,
        ),
        child: animated,
      ),
    );
  }
}
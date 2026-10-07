import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:img_syncer/app/theme/design_tokens.dart';
import 'motion_controller.dart';

/// MIUIX 液态玻璃面板表面 + 跟随手指的「凝光」层。
///
/// 组成：背景模糊 → 半透明渐变底 → 高光描边 → 凝光层（径向柔光，随手指移动）。
///
/// 性能约定：
/// - 凝光由 [ValueNotifier] 驱动，**只重绘凝光这一层**（`RepaintBoundary` + `CustomPainter`），
///   不会重建面板子树；
/// - 展开动画期间建议 [enableBlur] = false —— `BackdropFilter` 逐帧重算代价高。
class MiuixGlassSurface extends StatefulWidget {
  const MiuixGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.extraLarge,
    this.corners,
    this.blurSigma = 20,
    this.enableBlur = true,
  });

  final Widget child;
  final double borderRadius;

  /// 精确指定四角圆角（如底部弹层只需上方圆角）；非空时覆盖 [borderRadius]。
  final BorderRadius? corners;
  final double blurSigma;

  /// 是否启用背景模糊。展开/拖拽过程中应传 false。
  final bool enableBlur;

  @override
  State<MiuixGlassSurface> createState() => _MiuixGlassSurfaceState();
}

class _MiuixGlassSurfaceState extends State<MiuixGlassSurface> {
  /// 手指在面板内的位置。只驱动凝光层重绘。
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = widget.corners ?? BorderRadius.circular(widget.borderRadius);

    final glassBase = isDark ? cs.surfaceContainerHigh : cs.surface;
    final glassTop = glassBase.withValues(alpha: isDark ? 0.72 : 0.86);
    final glassBottom = glassBase.withValues(alpha: isDark ? 0.50 : 0.62);
    final hairline = cs.onSurface.withValues(alpha: isDark ? 0.16 : 0.10);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[glassTop, glassBottom],
        ),
        borderRadius: radius,
        border: Border.all(color: hairline, width: 0.8),
      ),
      child: widget.child,
    );

    if (widget.enableBlur) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: widget.blurSigma,
          sigmaY: widget.blurSigma,
        ),
        child: surface,
      );
    }

    if (motionController.bloomEnabled) {
      surface = Stack(
        children: <Widget>[
          surface,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: MiuixBloomPainter(
                    pointer: _pointer,
                    glowColor: isDark ? Colors.white : Colors.white,
                    tint: cs.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _pointer.value = e.localPosition,
      onPointerMove: (e) => _pointer.value = e.localPosition,
      onPointerUp: (_) => _pointer.value = null,
      onPointerCancel: (_) => _pointer.value = null,
      child: ClipRRect(borderRadius: radius, child: surface),
    );
  }
}

/// 凝光：手指处一团柔光（径向渐变 + `BlendMode.plus` 叠加）。
///
/// 只依赖 [pointer] 这一个 `ValueListenable` 重绘，不触碰 widget 树。
class MiuixBloomPainter extends CustomPainter {
  MiuixBloomPainter({
    required this.pointer,
    required this.glowColor,
    required this.tint,
  }) : super(repaint: pointer);

  final ValueListenable<Offset?> pointer;
  final Color glowColor;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pointer.value;
    if (p == null) return;
    final radius = size.longestSide * 0.45;
    final shader = RadialGradient(
      colors: <Color>[
        glowColor.withValues(alpha: 0.20),
        tint.withValues(alpha: 0.06),
        glowColor.withValues(alpha: 0.0),
      ],
      stops: const <double>[0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: p, radius: radius));

    canvas.drawCircle(
      p,
      radius,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant MiuixBloomPainter oldDelegate) =>
      oldDelegate.glowColor != glowColor || oldDelegate.tint != tint;
}
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:img_syncer/app/theme/design_tokens.dart';
import 'motion_controller.dart';

/// 果冻拖拽容器。
///
/// - **任意位置可拖**：[pointerDrag] 为 true 时用裸指针事件（`Listener`）跟踪 ——
///   裸指针**不参与手势竞技场**，所以不管落点在标题、选项行还是空白处都能拖动，
///   不会被子组件（如 `InkWell`、可滚动列表）抢走手势。
///   同时用单个 `onPan*` 而非 `onVerticalDrag*` + `onHorizontalDrag*` —— 后者是两个
///   互斥识别器，竞技场里同一时刻只有一个能赢，斜着拖只能沿一个轴移动。
/// - **任意方向**：位移按二维累加，跟手 1:1。
/// - 纵向下拉超过阈值或向下甩出 → 关闭；否则弹簧回弹。
/// - 拖动时带轻微拉伸/压扁/倾斜的「果冻」形变；仅 [MotionLevel.full] 启用。
///
/// 内容可滚动时（如下拉选项超出一屏）应传 `pointerDrag: false` —— 否则拖拽会把
/// 滚动顶掉；此时由顶部抓手 [MiuixOverlayGrip]（无竞争手势）承担下拉关闭。
class JellyDragContainer extends StatefulWidget {
  const JellyDragContainer({
    super.key,
    required this.child,
    required this.onDismiss,
    this.dragToDismiss = true,
    this.pointerDrag = true,
    this.dismissThreshold = 96,
  });

  final Widget child;

  /// 达到关闭条件时调用（通常是 `Navigator.pop`）。
  final VoidCallback onDismiss;

  /// 是否允许下拉关闭。
  final bool dragToDismiss;

  /// 是否用裸指针事件跟踪拖拽（保证任意位置可拖）。
  final bool pointerDrag;

  /// 纵向拖过该像素数即关闭。
  final double dismissThreshold;

  @override
  State<JellyDragContainer> createState() => _JellyDragContainerState();
}

class _JellyDragContainerState extends State<JellyDragContainer>
    with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  Offset _releaseFrom = Offset.zero;
  bool _dismissing = false;

  /// 正在跟踪的指针 id（只跟第一根手指，忽略多指）。
  int? _activePointer;

  /// 粗略估算的纵向速度（px/s），用于判定"向下甩出"。
  Duration? _lastStamp;
  double _vDy = 0;

  /// unbounded：弹簧可以过冲到 0 之外，形成"果冻余韵"。
  late final AnimationController _spring =
      AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    _spring.addListener(() {
      if (!mounted) return;
      setState(() {
        _drag = Offset.lerp(_releaseFrom, Offset.zero, _spring.value) ??
            Offset.zero;
      });
    });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  // ── 裸指针路径（任意位置可拖）────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    if (_dismissing) return;
    _activePointer ??= event.pointer;
    if (_activePointer == event.pointer) {
      _lastStamp = event.timeStamp;
      _vDy = 0;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dismissing || event.pointer != _activePointer) return;
    final last = _lastStamp;
    if (last != null) {
      final dt = (event.timeStamp - last).inMicroseconds / 1000000.0;
      if (dt > 0.001) _vDy = event.delta.dy / dt;
    }
    _lastStamp = event.timeStamp;
    setState(() {
      _drag += event.delta;
    });
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _finishDrag();
  }

  // ── 手势路径（内容可滚动时，靠抓手拖）────────────────

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    setState(() {
      _drag += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dismissing) return;
    _vDy = details.velocity.pixelsPerSecond.dy;
    _finishDrag();
  }

  /// 松手结算：过阈值/向下甩 → 关闭；否则弹簧回弹。
  void _finishDrag() {
    if (_dismissing) return;

    final overThreshold = _drag.dy > widget.dismissThreshold;
    final flungDown = _vDy > 900;

    if (widget.dragToDismiss && (overThreshold || flungDown)) {
      _dismissing = true;
      widget.onDismiss();
      return;
    }

    // 弹簧回弹：full 档位降低阻尼并给初始速度，回弹带"果冻"过冲
    final jelly = motionController.jellyEnabled;
    _releaseFrom = _drag;
    _spring.value = 0;
    _spring.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: 420,
          damping: jelly ? 17 : 30,
        ),
        0,
        1,
        jelly ? 1.8 : 1.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jelly = motionController.jellyEnabled;
    final dx = _drag.dx;
    final dy = _drag.dy;

    // 纵向拉得越远越"拉长压扁"，横向越远越倾斜 —— 果冻形变
    final stretchY = jelly ? (dy.abs() / 900).clamp(0.0, 0.05) : 0.0;
    final squashX = jelly ? (dy.abs() / 1400).clamp(0.0, 0.03) : 0.0;
    final angle = jelly ? (dx / 2400).clamp(-0.04, 0.04) : 0.0;

    final Widget draggable = widget.pointerDrag
        ? Listener(
            // opaque：整个面板矩形都能收到指针事件（含边缘与空白处）
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: widget.child,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: widget.child,
          );

    return Transform.translate(
      offset: _drag,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scaleX: 1 - squashX,
          scaleY: 1 + stretchY,
          child: draggable,
        ),
      ),
    );
  }
}

/// 浮层顶部的「抓手」：不可滚动区域，供纵向拖动触发下拉关闭。
///
/// 面板内容为可滚动列表且已关闭裸指针拖拽（`pointerDrag: false`）时，
/// 这是唯一可用的下拉关闭入口。
class MiuixOverlayGrip extends StatelessWidget {
  const MiuixOverlayGrip({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppSpacing.md + 4,
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.buttonFull),
          ),
        ),
      ),
    );
  }
}
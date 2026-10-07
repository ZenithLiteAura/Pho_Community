import 'package:flutter/widgets.dart';

/// 记录「最近一次手指按下的屏幕坐标」，作为浮层展开动画的原点。
///
/// 用法：在 app 根部（`MaterialApp.builder`）包一层 [wrap]，
/// 之后任何 `showDialog` / 浮层入口都能直接读 [last]，
/// 无需逐个调用点传参。
///
/// 读取不到时返回 null，浮层退化为居中展开。
class MotionOrigin {
  MotionOrigin._();

  static Offset? _last;

  /// 最近一次按下的全局坐标（可能为 null）。
  static Offset? get last => _last;

  /// 记录按下位置。
  static void record(Offset position) {
    _last = position;
  }

  /// 清除记录（例如指针抬起后）。
  static void clear() {
    _last = null;
  }

  /// 包一层监听：记录按下位置，并把移动/抬起事件透传给子树。
  static Widget wrap({required Widget child}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => record(event.position),
      child: child,
    );
  }
}
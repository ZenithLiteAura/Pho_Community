import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:img_syncer/app/theme/design_tokens.dart';

/// 顶部液态玻璃提示条。
///
/// 设计目标：替代默认贴底的 SnackBar —— 提示从屏幕顶部（状态栏下方）浮出，
/// 宽度收窄居中，带背景模糊 / 半透明渐变 / 高光描边 / 柔和投影，
/// 不再遮挡底部悬浮 Dock 与页面主要操作区。
///
/// 对外只暴露 [show]；[SnackBarManager] 是唯一入口，调用方无需感知实现。
class LiquidGlassToast {
  LiquidGlassToast._();

  /// 默认展示时长。
  static const Duration defaultDuration = Duration(seconds: 3);

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// 在 [context] 所在的**根** Overlay 顶部显示一条提示。
  ///
  /// 连续调用时替换上一条（不排队），避免同步过程中提示堆叠成摞。
  /// 若 Overlay 不可用（context 已失效等），降级为原生 SnackBar，保证提示不丢失。
  static void show(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
  }) {
    if (message.trim().isEmpty) return;

    OverlayState? overlay;
    try {
      overlay = Overlay.maybeOf(context, rootOverlay: true);
    } catch (_) {
      overlay = null;
    }

    if (overlay == null || !overlay.mounted) {
      _fallback(context, message);
      return;
    }

    dismiss();

    final entry = OverlayEntry(
      builder: (_) => _LiquidGlassToastView(
        message: message,
        onDismiss: dismiss,
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }

  /// 降级路径：Overlay 不可用（context 失效或正在销毁）时，用原生 SnackBar 兜底，
/// 保证提示不丢失。其外观由 SnackBarThemeData 控制，已与玻璃条对齐。
  static void _fallback(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 立即移除当前提示（若存在）。
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }
}

/// 提示条本体：顶部锚定、宽度受限、玻璃质感。
///
/// 顶部锚定（而非底部）意味着多行文本向下自然扩展，不会顶进状态栏。
class _LiquidGlassToastView extends StatefulWidget {
  const _LiquidGlassToastView({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_LiquidGlassToastView> createState() => _LiquidGlassToastViewState();
}

class _LiquidGlassToastViewState extends State<_LiquidGlassToastView>
    with SingleTickerProviderStateMixin {
  static const Duration _enterDuration = Duration(milliseconds: 240);
  static const Duration _exitDuration = Duration(milliseconds: 180);

  /// 玻璃模糊半径。与底部 Dock 的「强模糊」档位同源，保持观感一致。
  static const double _blurSigma = 24;

  /// 提示条最大宽度：宽屏 / 桌面端不铺满，手机端约屏宽的 88%。
  static const double _maxWidth = 420;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _enterDuration,
    reverseDuration: _exitDuration,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  /// 自上而下轻微滑入，呼应「从顶部浮出」的方向感。
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -0.18),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    // 收窄宽度：左右各留 24，且不超过 420。
    final maxWidth = math.min(media.size.width - (AppSpacing.lg * 2), _maxWidth);

    // 玻璃底色：浅色用 surface（白），深色用 surfaceContainerHigh（深灰）。
    final glassBase = isDark ? cs.surfaceContainerHigh : cs.surface;
    final glassTop = glassBase.withValues(alpha: isDark ? 0.74 : 0.84);
    final glassBottom = glassBase.withValues(alpha: isDark ? 0.52 : 0.58);
    // 高光描边：玻璃边缘的细亮线，深色主题下更明显一些。
    final hairline = cs.onSurface.withValues(alpha: isDark ? 0.16 : 0.10);

    return Positioned(
      top: media.padding.top + AppSpacing.xs,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Semantics(
                liveRegion: true,
                label: widget.message,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDismiss,
                  child: DecoratedBox(
                    // 投影在 ClipRRect 之外，避免被裁剪掉。
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: cs.scrim.withValues(alpha: 0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: _blurSigma,
                          sigmaY: _blurSigma,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[glassTop, glassBottom],
                            ),
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: hairline, width: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              fontFamily: AppFonts.body,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
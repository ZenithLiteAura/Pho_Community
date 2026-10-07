import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:img_syncer/app/theme/design_tokens.dart';

/// 选项行高（对齐 MIUIX DropdownDefaults.MinHeight = 56dp）。
const double _kOptionHeight = 56;

/// 面板最小宽度（对齐 MIUIX DropdownDefaults.MinWidth = 200dp）。
const double _kPanelMinWidth = 200;

/// 收起态额外补偿（对齐 OverlayDropdownMenu 的 DefaultCollapseExtra = 14dp x 10dp）。
const Size _kCollapseExtra = Size(14, 10);

/// MIUIX 风格下拉的单个选项。
class MiuixDropdownItem<T> {
  const MiuixDropdownItem({
    required this.value,
    required this.label,
    this.summary,
    this.icon,
  });

  final T value;
  final String label;

  /// 可选的第二行说明（对齐 MIUIX DropdownItem.summary）。
  final String? summary;

  /// 可选的左侧图标。
  final IconData? icon;
}

/// 动作菜单里的一项（不走选中态，只回传点击）。
class MiuixActionItem {
  const MiuixActionItem({
    required this.label,
    this.summary,
    this.icon,
    this.danger = false,
    this.enabled = true,
  });

  final String label;
  final String? summary;
  final IconData? icon;

  /// 危险项：文字用错误色。
  final bool danger;
  final bool enabled;
}

/// 面板内部统一条目：选中型与动作型共用同一套渲染与跟手滑选。
class _PanelEntry {
  const _PanelEntry({
    required this.label,
    this.summary,
    this.icon,
    this.selected = false,
    this.danger = false,
    this.enabled = true,
    this.value,
  });

  final String label;
  final String? summary;
  final IconData? icon;
  final bool selected;
  final bool danger;
  final bool enabled;
  final Object? value;
}

/// 弹出 MIUIX 锚定下拉：**从触发区那坨「当前值 + 箭头」原地长成菜单**，
/// 选中后缩回原处。取消 / 点外部返回 `null`。
///
/// 交互与参数对齐 NexioSchedule 里用到的 MIUIX 实现：
///  - 面板右对齐触发区（`PopupPositionProvider.Align.End`）；
///  - 收起态尺寸 = 触发区实测尺寸 + [collapseExtra]，从该矩形 lerp 到展开态；
///  - 每项最小高度 56、面板最小宽度 200；选中项主色文字 + 底色 + 指示条 + 勾；
///  - 选项放得下时支持按住上下滑的「跟手滑选」。
Future<T?> showMiuixDropdown<T>({
  required BuildContext context,
  String? title,
  required List<MiuixDropdownItem<T>> items,
  required T current,
  Rect? anchorRect,
}) {
  if (items.isEmpty) return Future<T?>.value();
  final entries = items
      .map((item) => _PanelEntry(
            label: item.label,
            summary: item.summary,
            icon: item.icon,
            selected: item.value == current,
            value: item.value,
          ))
      .toList(growable: false);
  return _showMiuixPanel<T>(context: context, title: title, entries: entries, anchorRect: anchorRect);
}

/// 弹出 MIUIX 锚定动作菜单（与下拉共用同一套外观与动效）。
///
/// 返回被点击项的下标；取消返回 `null`。
Future<int?> showMiuixActionMenu({
  required BuildContext context,
  String? title,
  required List<MiuixActionItem> items,
  Rect? anchorRect,
}) {
  if (items.isEmpty) return Future<int?>.value();
  final entries = <_PanelEntry>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    entries.add(_PanelEntry(
      label: item.label,
      summary: item.summary,
      icon: item.icon,
      danger: item.danger,
      enabled: item.enabled,
      value: i,
    ));
  }
  return _showMiuixPanel<int>(context: context, title: title, entries: entries, anchorRect: anchorRect);
}

/// 通用锚定面板。内部使用；对外只用 [showMiuixDropdown] / [showMiuixActionMenu]。
Future<T?> _showMiuixPanel<T>({
  required BuildContext context,
  String? title,
  required List<_PanelEntry> entries,
  Rect? anchorRect,
}) {
  final media = MediaQuery.of(context);
  // 没有锚点信息时贴屏幕中下方展开，保证功能可用。
  final anchor = anchorRect ??
      Rect.fromLTWH(media.size.width / 2 - 60, media.size.height * 0.66, 120, 44);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // 自己画压暗（对应 MIUIX 的 enableWindowDim），让遮罩能随形变淡入
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) => _AnchoredMiuiPanel<T>(
      title: title,
      entries: entries,
      anchor: anchor,
    ),
  );
}

class _AnchoredMiuiPanel<T> extends StatefulWidget {
  const _AnchoredMiuiPanel({
    required this.title,
    required this.entries,
    required this.anchor,
  });

  final String? title;
  final List<_PanelEntry> entries;
  final Rect anchor;

  @override
  State<_AnchoredMiuiPanel<T>> createState() => _AnchoredMiuiPanelState<T>();
}

class _AnchoredMiuiPanelState<T> extends State<_AnchoredMiuiPanel<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 240),
  );

  /// 形变进度：进场轻过冲（近似 spring(0.78, 232)），退场更干脆（近似 spring(0.78, 400)）。
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  late Rect _collapsed;
  late Rect _expanded;
  int? _hotIndex;
  bool _started = false;

  // 尺寸依赖 MediaQuery，必须放在 didChangeDependencies（initState 里不能查 MediaQuery）。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layout();
    if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  void _layout() {
    final media = MediaQuery.of(context);
    final safe = media.padding;

    _collapsed = Rect.fromLTWH(
      widget.anchor.left - _kCollapseExtra.width / 2,
      widget.anchor.top - _kCollapseExtra.height / 2,
      widget.anchor.width + _kCollapseExtra.width,
      widget.anchor.height + _kCollapseExtra.height,
    );

    final panelWidth = math.max(
      _kPanelMinWidth,
      math.min(
        _measurePanelWidth(widget.entries) + AppSpacing.md * 2 + 8,
        media.size.width - AppSpacing.lg * 2,
      ),
    );
    final titleHeight = widget.title == null ? 0.0 : 34.0;
    final separators = widget.entries.length - 1;
    final panelHeight = math.min(
      titleHeight + widget.entries.length * _kOptionHeight + 12 + separators * 0.0,
      media.size.height * 0.6,
    );

    // 右对齐触发区（MIUIX 的 Align.End），并夹在安全区内。
    var left = widget.anchor.right - panelWidth + 8;
    left = left.clamp(safe.left + AppSpacing.sm, media.size.width - panelWidth - AppSpacing.sm);
    var top = widget.anchor.top - 6;
    top = top.clamp(safe.top + AppSpacing.sm, media.size.height - panelHeight - AppSpacing.sm);
    _expanded = Rect.fromLTWH(left, top, panelWidth, panelHeight);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _measurePanelWidth(List<_PanelEntry> entries) {
    var widest = 0.0;
    for (final e in entries) {
      final painter = TextPainter(
        text: TextSpan(
          text: e.label,
          style: const TextStyle(fontSize: 15, fontFamily: AppFonts.body),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      widest = math.max(widest, painter.width);
      final sub = e.summary;
      if (sub != null && sub.isNotEmpty) {
        final subPainter = TextPainter(
          text: TextSpan(
            text: sub,
            style: const TextStyle(fontSize: 12.5, fontFamily: AppFonts.body),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        widest = math.max(widest, subPainter.width);
      }
    }
    // 勾选图标 + 指示条 + 内边距的固定开销
    return widest + 64;
  }

  Future<void> _select(_PanelEntry entry) async {
    if (!entry.enabled) return;
    await _controller.reverse();
    if (!mounted) return;
    // 选中型回传值；动作型回传下标（两者都存在 value 里）
    Navigator.of(context).pop(entry.value as T?);
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  int? _indexAt(Offset globalPosition) {
    final local = globalPosition - _expanded.topLeft;
    final titleHeight = widget.title == null ? 0.0 : 34.0;
    final y = local.dy - 6 - titleHeight;
    if (y < 0) return null;
    final index = (y / _kOptionHeight).floor();
    if (index < 0 || index >= widget.entries.length) return null;
    return index;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final raw = _progress.value;
        final t = raw.clamp(0.0, 1.0);
        final rect = Rect.lerp(_collapsed, _expanded, t)!;
        final radius = BorderRadius.lerp(
          BorderRadius.circular(rect.height / 2),
          BorderRadius.circular(AppRadius.extraLarge),
          t,
        )!;
        return Stack(
          children: [
            // 压暗层（启用时随形变淡入）
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: cs.scrim.withValues(alpha: 0.10 * t),
                ),
              ),
            ),
            // 点空白处关闭
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: _PanelSurface(
                radius: radius,
                progress: t,
                title: widget.title,
                entries: widget.entries,
                expanded: rect,
                onSelect: _select,
                onHotChanged: (i) => setState(() => _hotIndex = i),
                hotIndex: _hotIndex,
                indexAt: _indexAt,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PanelSurface extends StatelessWidget {
  const _PanelSurface({
    required this.radius,
    required this.progress,
    required this.title,
    required this.entries,
    required this.expanded,
    required this.onSelect,
    required this.onHotChanged,
    required this.hotIndex,
    required this.indexAt,
  });

  final BorderRadius radius;
  final double progress;
  final String? title;
  final List<_PanelEntry> entries;
  final Rect expanded;
  final Future<void> Function(_PanelEntry entry) onSelect;
  final ValueChanged<int?> onHotChanged;
  final int? hotIndex;
  final int? Function(Offset globalPosition) indexAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = cs.brightness == Brightness.dark;
    // 面板底色与描边一律走主题色，避免硬编码颜色（仓库里有硬编码颜色门禁）
    final panelBase =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest;

    // 菜单内容随形变进度淡入（对应 ListPopupContent 用 fraction 驱动 alpha）
    final contentOpacity = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    final fits = entries.length * _kOptionHeight <= MediaQuery.sizeOf(context).height * 0.6;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cs.scrim.withValues(alpha: 0.16),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: cs.scrim.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: panelBase.withValues(alpha: isDark ? 0.80 : 0.84),
              borderRadius: radius,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.55),
              ),
            ),
            child: Opacity(
              opacity: contentOpacity,
              // 面板是直接挂在 dialog route 上的，InkWell 需要一个 Material 祖先
              child: Material(
                type: MaterialType.transparency,
                // 只响应点击，不做拖拽/跟手滑选
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          10,
                          AppSpacing.md,
                          6,
                        ),
                        child: Text(
                          title!,
                          style: textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: fits
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        itemCount: entries.length,
                        itemBuilder: (ctx, index) {
                          final entry = entries[index];
                          final selected = entry.selected;
                          final hot = hotIndex == index;
                          final baseColor = entry.danger
                              ? cs.error
                              : (selected ? cs.primary : cs.onSurface);
                          return InkWell(
                            onTap: entry.enabled ? () => onSelect(entry) : null,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: _kOptionHeight),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
                                    : (hot
                                        ? cs.onSurface.withValues(alpha: 0.06)
                                        : Colors.transparent),
                                borderRadius: BorderRadius.circular(AppRadius.small),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm + 2,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    child: selected
                                        ? Icon(Icons.check, size: 18, color: cs.primary)
                                        : (entry.icon != null
                                            ? Icon(entry.icon, size: 20, color: baseColor)
                                            : null),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          entry.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontFamily: AppFonts.body,
                                            color: entry.enabled
                                                ? baseColor
                                                : cs.onSurfaceVariant.withValues(alpha: 0.5),
                                            fontWeight: selected ? FontWeight.w600 : null,
                                          ),
                                        ),
                                        if (entry.summary != null && entry.summary!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              entry.summary!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.bodySmall?.copyWith(
                                                fontFamily: AppFonts.body,
                                                color: selected
                                                    ? cs.primary
                                                    : cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // 选中指示条（对齐 selectedIndicatorColor）
                                  Container(
                                    width: 3,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: selected ? cs.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 触发区实测矩形（用于形变起点与右对齐）。
Rect? miuixTriggerRect(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  final topLeft = box.localToGlobal(Offset.zero);
  return topLeft & box.size;
}

/// 表单场景的 MIUIX 下拉触发器。
///
/// 用 [InputDecorator] 承载内容，因此自动继承 app 的 `inputDecorationTheme`；
/// 右侧「当前值 + 箭头」既是触发区，也是浮层形变的起点。
class MiuixDropdownField<T> extends StatefulWidget {
  const MiuixDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<MiuixDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  State<MiuixDropdownField<T>> createState() => _MiuixDropdownFieldState<T>();
}

class _MiuixDropdownFieldState<T> extends State<MiuixDropdownField<T>> {
  final GlobalKey _triggerKey = GlobalKey();
  bool _open = false;

  String get _currentLabel {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }
    return widget.items.isEmpty ? '' : widget.items.first.label;
  }

  Future<void> _openPanel() async {
    setState(() => _open = true);
    final picked = await showMiuixDropdown<T>(
      context: context,
      title: widget.label,
      items: widget.items,
      current: widget.value,
      anchorRect: miuixTriggerRect(_triggerKey),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.input),
      onTap: widget.enabled ? _openPanel : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label,
          enabled: widget.enabled,
        ),
        isEmpty: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _currentLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontFamily: AppFonts.body,
                      color: widget.enabled ? cs.onSurface : cs.onSurfaceVariant,
                    ),
              ),
            ),
            // 展开时触发区「硬切」隐藏，由浮层自己画收起态，形成「从这坨长出来」的错觉
            Visibility(
              visible: !_open,
              maintainSize: true,
              maintainState: true,
              maintainAnimation: true,
              child: Row(
                key: _triggerKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.expand_more,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表 / 偏好行场景的 MIUIX 下拉触发器。
///
/// 左侧标题，右侧「当前值 + 下拉箭头」；点开后浮层从那坨内容原地长成菜单。
class MiuixDropdownTile<T> extends StatefulWidget {
  const MiuixDropdownTile({
    super.key,
    this.leading,
    required this.title,
    this.summary,
    required this.value,
    required this.items,
    required this.onChanged,
    this.valueText,
  });

  final Widget? leading;
  final String title;
  final String? summary;
  final T value;
  final List<MiuixDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  /// 右侧显示文本；为 null 时显示选中项的 label。
  final String? valueText;

  @override
  State<MiuixDropdownTile<T>> createState() => _MiuixDropdownTileState<T>();
}

class _MiuixDropdownTileState<T> extends State<MiuixDropdownTile<T>> {
  final GlobalKey _triggerKey = GlobalKey();
  bool _open = false;

  String get _currentLabel {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }
    return widget.items.isEmpty ? '' : widget.items.first.label;
  }

  Future<void> _openPanel() async {
    setState(() => _open = true);
    final picked = await showMiuixDropdown<T>(
      context: context,
      title: widget.title,
      items: widget.items,
      current: widget.value,
      anchorRect: miuixTriggerRect(_triggerKey),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: widget.leading,
      title: Text(widget.title),
      subtitle: widget.summary == null ? null : Text(widget.summary!),
      trailing: Visibility(
        visible: !_open,
        maintainSize: true,
        maintainState: true,
        maintainAnimation: true,
        child: Row(
          key: _triggerKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.valueText ?? _currentLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontFamily: AppFonts.body,
                  ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.expand_more, color: cs.onSurfaceVariant),
          ],
        ),
      ),
      onTap: _openPanel,
    );
  }
}

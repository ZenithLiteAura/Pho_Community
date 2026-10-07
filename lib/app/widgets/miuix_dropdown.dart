import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/motion/miuix_overlay.dart';

/// 选项行高：浮层绘制与「全部选项能否一次放下」的判断共用同一常量。
const double _kOptionHeight = 52;

/// MIUIX 风格下拉的单个选项。
class MiuixDropdownItem<T> {
  const MiuixDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;

  /// 可选的左侧图标。
  final IconData? icon;
}

/// 选项能否一次放下（一屏内）。
///
/// 决定两件事，且两处必须用同一判断，否则会出现"能拖但列表抢手势"的矛盾状态：
///  - 列表是否可滚动（放得下就不滚动）；
///  - 是否启用裸指针拖拽（放得下才能任意位置拖，否则靠顶部抓手）。
bool _dropdownItemsFit(BuildContext context, int count) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  return count * _kOptionHeight <= screenHeight * 0.6;
}

/// 弹出 MIUIX 风格选择浮层，返回选中值。
///
/// 取消或点击浮层外部返回 `null`（调用方据此不做变更）。
/// 视觉：大圆角（28）浅色面板 + 柔和阴影 + 选项勾选 + 底部独立「取消」行，
/// 对应 miuix 的 OverlayDropdown 交互，而非 Material 的原始弹出菜单。
Future<T?> showMiuixDropdown<T>({
  required BuildContext context,
  String? title,
  required List<MiuixDropdownItem<T>> items,
  required T current,
}) {
  final fits = _dropdownItemsFit(context, items.length);
  return showMiuixOverlay<T>(
    context: context,
    // 抓手始终提供：选项超出一屏时它是唯一的下拉关闭入口
    showGrip: true,
    dragToDismiss: true,
    // 选项放得下 → 用裸指针，整框任意位置可拖；
    // 选项放不下（列表必须滚动）→ 交给抓手，避免拖拽把滚动顶掉
    pointerDrag: fits,
    builder: (ctx) => _MiuixDropdownPanel<T>(
      title: title,
      items: items,
      current: current,
    ),
  );
}

class _MiuixDropdownPanel<T> extends StatelessWidget {
  const _MiuixDropdownPanel({
    this.title,
    required this.items,
    required this.current,
  });

  final String? title;
  final List<MiuixDropdownItem<T>> items;
  final T current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    final maxWidth = math.min(size.width - AppSpacing.lg * 2, 420.0);
    final maxHeight = size.height * 0.6;
    // 放得下就禁用列表滚动：避免列表抢走纵向手势，使「整个框」都能任意方向拖。
    final fitsAll = _dropdownItemsFit(context, items.length);

    return Center(
      child: Container(
        width: maxWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.extraLarge),
          // 阴影放在 Material 之外，否则会被 Material 裁掉
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: cs.scrim.withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          // 由 MiuixGlassSurface 提供玻璃表面，这里保持透明以便透出玻璃与凝光
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.extraLarge),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm + 2,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title!,
                      style: textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: fitsAll
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemCount: items.length,
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    final selected = item.value == current;
                    final color = selected ? cs.primary : cs.onSurface;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, item.value),
                      child: SizedBox(
                        height: _kOptionHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              if (item.icon != null) ...[
                                Icon(item.icon, size: 22, color: color),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              Expanded(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: color,
                                    fontFamily: AppFonts.body,
                                    fontWeight:
                                        selected ? FontWeight.w600 : null,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check, size: 20, color: cs.primary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  height: 52,
                  child: Center(
                    child: Text(
                      l10n.cancel,
                      style: textTheme.bodyLarge?.copyWith(
                        color: cs.primary,
                        fontFamily: AppFonts.body,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表单场景的 MIUIX 下拉触发器。
///
/// 用 [InputDecorator] 承载内容，因此自动继承 app 的 `inputDecorationTheme`
/// （MIUIX 模式为 surfaceTertiary 填充 + 14 圆角 + 无边框），
/// 与相邻的 `TextFormField` 视觉完全一致。
class MiuixDropdownField<T> extends StatelessWidget {
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

  String get _currentLabel {
    for (final item in items) {
      if (item.value == value) return item.label;
    }
    return items.isEmpty ? '' : items.first.label;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.input),
      onTap: enabled
          ? () async {
              final picked = await showMiuixDropdown<T>(
                context: context,
                title: label,
                items: items,
                current: value,
              );
              if (picked != null) onChanged(picked);
            }
          : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
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
                      color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                    ),
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 22,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表/偏好行场景的 MIUIX 下拉触发器。
///
/// 左侧标题、右侧「当前值（主色）+ 箭头」，点击打开同一浮层。
class MiuixDropdownTile<T> extends StatelessWidget {
  const MiuixDropdownTile({
    super.key,
    this.leading,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.valueText,
  });

  final Widget? leading;
  final String title;
  final T value;
  final List<MiuixDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  /// 右侧显示文本；为 null 时显示选中项的 label。
  final String? valueText;

  String get _currentLabel {
    for (final item in items) {
      if (item.value == value) return item.label;
    }
    return items.isEmpty ? '' : items.first.label;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: leading,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            valueText ?? _currentLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontFamily: AppFonts.body,
                ),
          ),
          const SizedBox(width: AppSpacing.base),
          Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: () async {
        final picked = await showMiuixDropdown<T>(
          context: context,
          title: title,
          items: items,
          current: value,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
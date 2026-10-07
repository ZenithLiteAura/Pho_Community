import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/theme/dock_style_controller.dart';
import 'package:img_syncer/app/widgets/miuix_dropdown.dart';

/// 二级页：Dock 设置 —— 风格、透明度、模糊度。
///
/// 三项都用 MIUIX 锚定下拉（点行 → 贴着右侧那坨「当前值 + 箭头」原地展开），
/// **不再弹对话框**：避免「玻璃盒 + AlertDialog 自带 Material」两层叠在一起、
/// 尺寸还不一致的问题，也顺带没有拖拽与凝光跟随手指。
class SettingsDockPage extends StatelessWidget {
  const SettingsDockPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dock ${l10n.appearanceAndTheme}')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Card(
            child: Consumer<DockStyleController>(
              builder: (context, controller, _) {
                return Column(
                  children: [
                    MiuixDropdownTile<DockStyle>(
                      leading: const Icon(Icons.layers_outlined, size: 26),
                      title: l10n.dockStyle,
                      value: controller.style,
                      valueText: _dockStyleLabel(controller.style),
                      items: [
                        MiuixDropdownItem(
                          value: DockStyle.frosted,
                          label: l10n.dockStyleFrosted,
                        ),
                        MiuixDropdownItem(
                          value: DockStyle.mica,
                          label: l10n.dockStyleMica,
                        ),
                        MiuixDropdownItem(
                          value: DockStyle.solid,
                          label: l10n.dockStyleSolid,
                        ),
                      ],
                      onChanged: controller.setStyle,
                    ),
                    const Divider(height: 1),
                    MiuixDropdownTile<DockOpacity>(
                      leading: const Icon(Icons.opacity_outlined, size: 26),
                      title: l10n.dockOpacity,
                      value: controller.opacity,
                      valueText: _dockOpacityLabel(controller.opacity),
                      items: [
                        MiuixDropdownItem(
                          value: DockOpacity.high,
                          label: l10n.dockOpacityHigh,
                        ),
                        MiuixDropdownItem(
                          value: DockOpacity.medium,
                          label: l10n.dockOpacityMedium,
                        ),
                        MiuixDropdownItem(
                          value: DockOpacity.low,
                          label: l10n.dockOpacityLow,
                        ),
                      ],
                      onChanged: controller.setOpacity,
                    ),
                    const Divider(height: 1),
                    MiuixDropdownTile<DockBlur>(
                      leading: const Icon(Icons.blur_on_outlined, size: 26),
                      title: l10n.dockBlur,
                      value: controller.blur,
                      valueText: _dockBlurLabel(controller.blur),
                      items: [
                        MiuixDropdownItem(
                          value: DockBlur.light,
                          label: l10n.dockBlurLight,
                        ),
                        MiuixDropdownItem(
                          value: DockBlur.medium,
                          label: l10n.dockBlurMedium,
                        ),
                        MiuixDropdownItem(
                          value: DockBlur.strong,
                          label: l10n.dockBlurStrong,
                        ),
                      ],
                      onChanged: controller.setBlur,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Dock 风格 → 显示文本。
  String _dockStyleLabel(DockStyle style) {
    if (style == DockStyle.frosted) return l10n.dockStyleFrosted;
    if (style == DockStyle.mica) return l10n.dockStyleMica;
    return l10n.dockStyleSolid;
  }

  /// Dock 透明度 → 显示文本。
  String _dockOpacityLabel(DockOpacity op) {
    if (op == DockOpacity.high) return l10n.dockOpacityHigh;
    if (op == DockOpacity.low) return l10n.dockOpacityLow;
    return l10n.dockOpacityMedium;
  }

  /// Dock 模糊度 → 显示文本。
  String _dockBlurLabel(DockBlur blur) {
    if (blur == DockBlur.light) return l10n.dockBlurLight;
    if (blur == DockBlur.strong) return l10n.dockBlurStrong;
    return l10n.dockBlurMedium;
  }
}

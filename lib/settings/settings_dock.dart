import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/settings/dock_style_controller.dart';

/// 二级页：Dock 设置 —— 风格、透明度、模糊度。
class SettingsDockPage extends StatelessWidget {
  const SettingsDockPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Dock ${l10n.appearanceAndTheme}')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // ── Dock 风格 ──
          Card(
            child: Consumer<DockStyleController>(
              builder: (context, controller, _) {
                final styleLabel = _dockStyleLabel(controller.style);
                return ListTile(
                  leading: const Icon(Icons.layers_outlined, size: 26),
                  title: Text(l10n.dockStyle),
                  subtitle: Text(
                    styleLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _showDockStyleDialog(context, controller),
                );
              },
            ),
          ),
          // ── Dock 透明度 ──
          Card(
            child: Consumer<DockStyleController>(
              builder: (context, controller, _) {
                final opLabel = _dockOpacityLabel(controller.opacity);
                return ListTile(
                  leading: const Icon(Icons.opacity_outlined, size: 26),
                  title: Text(l10n.dockOpacity),
                  subtitle: Text(
                    opLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _showDockOpacityDialog(context, controller),
                );
              },
            ),
          ),
          // ── Dock 模糊度 ──
          Card(
            child: Consumer<DockStyleController>(
              builder: (context, controller, _) {
                final blurLabel = _dockBlurLabel(controller.blur);
                return ListTile(
                  leading: const Icon(Icons.blur_on_outlined, size: 26),
                  title: Text(l10n.dockBlur),
                  subtitle: Text(
                    blurLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _showDockBlurDialog(context, controller),
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

  /// Dock 风格弹窗。
  void _showDockStyleDialog(BuildContext context, DockStyleController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dockStyle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<DockStyle>(
              title: Text(l10n.dockStyleFrosted),
              value: DockStyle.frosted,
              groupValue: controller.style,
              onChanged: (v) {
                if (v != null) controller.setStyle(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<DockStyle>(
              title: Text(l10n.dockStyleMica),
              value: DockStyle.mica,
              groupValue: controller.style,
              onChanged: (v) {
                if (v != null) controller.setStyle(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<DockStyle>(
              title: Text(l10n.dockStyleSolid),
              value: DockStyle.solid,
              groupValue: controller.style,
              onChanged: (v) {
                if (v != null) controller.setStyle(v);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// Dock 透明度弹窗。
  void _showDockOpacityDialog(BuildContext context, DockStyleController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dockOpacity),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<DockOpacity>(
              title: Text(l10n.dockOpacityHigh),
              value: DockOpacity.high,
              groupValue: controller.opacity,
              onChanged: (v) {
                if (v != null) controller.setOpacity(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<DockOpacity>(
              title: Text(l10n.dockOpacityMedium),
              value: DockOpacity.medium,
              groupValue: controller.opacity,
              onChanged: (v) {
                if (v != null) controller.setOpacity(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<DockOpacity>(
              title: Text(l10n.dockOpacityLow),
              value: DockOpacity.low,
              groupValue: controller.opacity,
              onChanged: (v) {
                if (v != null) controller.setOpacity(v);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  /// Dock 模糊度弹窗。
  void _showDockBlurDialog(BuildContext context, DockStyleController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dockBlur),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<DockBlur>(
              title: Text(l10n.dockBlurLight),
              value: DockBlur.light,
              groupValue: controller.blur,
              onChanged: (v) {
                if (v != null) controller.setBlur(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<DockBlur>(
              title: Text(l10n.dockBlurMedium),
              value: DockBlur.medium,
              groupValue: controller.blur,
              onChanged: (v) {
                if (v != null) controller.setBlur(v);
                Navigator.pop(context);
              },
            ),
            RadioListTile<DockBlur>(
              title: Text(l10n.dockBlurStrong),
              value: DockBlur.strong,
              groupValue: controller.blur,
              onChanged: (v) {
                if (v != null) controller.setBlur(v);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import 'package:img_syncer/app/state/global.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/motion/motion_controller.dart';

/// 三级页：动效 —— 弹层/浮层的动效强度（完整 / 简约 / 关闭）。
///
/// 对应 [MotionLevel]：控制「从触点展开」「凝光」「果冻拖拽」三项是否启用，
/// 供低端机或偏好省电的用户下调。
class SettingsMotionPage extends StatelessWidget {
  const SettingsMotionPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.motion)),
      body: ListenableBuilder(
        listenable: motionController,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              Card(
                child: Column(
                  children: [
                    _option(
                      context,
                      MotionLevel.full,
                      l10n.motionFull,
                      l10n.motionDescFull,
                    ),
                    const Divider(height: 1),
                    _option(
                      context,
                      MotionLevel.simple,
                      l10n.motionSimple,
                      l10n.motionDescSimple,
                    ),
                    const Divider(height: 1),
                    _option(
                      context,
                      MotionLevel.off,
                      l10n.motionOff,
                      l10n.motionDescOff,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _option(
    BuildContext context,
    MotionLevel level,
    String title,
    String desc,
  ) {
    final cs = Theme.of(context).colorScheme;
    return RadioListTile<MotionLevel>(
      title: Text(title),
      subtitle: Text(
        desc,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      ),
      value: level,
      groupValue: motionController.level,
      onChanged: (v) {
        if (v != null) motionController.setLevel(v);
      },
    );
  }
}
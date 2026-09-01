import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/state_model.dart';

/// 三级页：相册列数 —— 2-10 列 Slider，实时生效。
///
/// v3.1 性能优化：
/// - Slider + 数字拆为独立 [_SliderRow] StatefulWidget
/// - 拖动期间 setState 只重建 ~100px 高的 Slider 行，不碰 Scaffold/Card/ListView
/// - 松手才同步到全局模型并持久化
class SettingsGalleryColumnsPage extends StatefulWidget {
  const SettingsGalleryColumnsPage({Key? key}) : super(key: key);

  @override
  State<SettingsGalleryColumnsPage> createState() =>
      _SettingsGalleryColumnsPageState();
}

class _SettingsGalleryColumnsPageState
    extends State<SettingsGalleryColumnsPage> {
  int _initialCount = 3;

  @override
  void initState() {
    super.initState();
    _initialCount = settingModel.galleryColumCount;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.galleryColumnCount)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // v3.1：Slider + 数字独立 StatefulWidget，setState 隔离
                  _SliderRow(
                    initialValue: _initialCount.toDouble(),
                    onChangedEnd: (count) async {
                      settingModel.setGalleryColumCount(count);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('galleryColumCount', count);
                    },
                  ),
                  Text(
                    l10n.galleryColumnCountDesc,
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 独立 StatefulWidget：大数字 + Slider。
/// setState 只在这个 ~100px 小区域内，不会重建父级 Scaffold/Card/ListView。
class _SliderRow extends StatefulWidget {
  const _SliderRow({
    required this.initialValue,
    required this.onChangedEnd,
  });

  final double initialValue;
  final ValueChanged<int> onChangedEnd;

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late double _dragValue;

  @override
  void initState() {
    super.initState();
    _dragValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_dragValue.round()}',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.columns,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          Slider(
            min: 2,
            max: 10,
            divisions: 8,
            value: _dragValue,
            label: '${_dragValue.round()}',
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
            },
            onChangeEnd: (value) {
              widget.onChangedEnd(value.round());
            },
          ),
        ],
      ),
    );
  }
}
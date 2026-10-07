import 'package:flutter/material.dart';

import 'package:img_syncer/app/pages/settings/settings_developer_announcement_manager.dart';
import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/announcement_dev_tools.dart';
import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/announcement_dialog.dart';
import 'package:img_syncer/app/widgets/liquid_glass_toast.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 开发者选项 → 公告：公告相关的只读测试工具都在这里。
///
/// - 测试拉取公告：逐个源看 HTTP/耗时/内容，确认哪条源在顶用；
/// - 测试弹窗公告：按**用户真实路径**判定一次，告诉你「会不会弹、为什么」；
/// - 公告管理工具：发布 / 下线 / 历史回滚等写操作。
class SettingsDeveloperAnnouncementPage extends StatefulWidget {
  const SettingsDeveloperAnnouncementPage({Key? key}) : super(key: key);

  @override
  State<SettingsDeveloperAnnouncementPage> createState() =>
      _SettingsDeveloperAnnouncementPageState();
}

class _SettingsDeveloperAnnouncementPageState
    extends State<SettingsDeveloperAnnouncementPage> {
  bool _busy = false;
  List<AnnouncementSourceProbe> _probes = const [];
  String _result = '';

  void _toast(String msg) {
    if (!mounted) return;
    LiquidGlassToast.show(context, msg);
    setState(() => _result = msg);
  }

  Future<void> _run(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } catch (e) {
      _toast('异常：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _probeSources() => _run(() async {
        final probes = await probeAnnouncementSources();
        if (!mounted) return;
        setState(() => _probes = probes);
        final usable = probes.where((p) => p.usable).length;
        final notify = probes.where((p) => p.wouldNotify).length;
        _toast('探测完成：可用 $usable/${probes.length} 条，其中 $notify 条会弹公告');
      });

  /// 按用户真实路径判定：拉取 → enabled → 时间窗口 → 版本区间 → 已读去重。
  Future<void> _testPopup() => _run(() async {
        final report = await fetchAnnouncementReport();
        final seenRaw = await readSeenAnnouncementIds();
        final seenIds = seenRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        final gate = AnnouncementGate.evaluate(
          announcement: report.announcement,
          anySourceUsable: report.anySourceUsable,
          now: DateTime.now(),
          appVersion: communityVersion,
          seenIds: seenIds,
        );

        if (gate.willShow && gate.announcement != null) {
          _toast('会弹：id=${gate.announcement!.id}（${gate.announcement!.level.name}）');
          if (!mounted) return;
          await showAnnouncementDialog(context, gate.announcement!);
          return;
        }
        _toast(_reasonText(gate.reason));
      });

  String _reasonText(AnnouncementGateReason reason) {
    switch (reason) {
      case AnnouncementGateReason.allSourcesFailed:
        return '不会弹：所有公告源都不可用';
      case AnnouncementGateReason.notEnabled:
        return '不会弹：源可用，但云端 enabled 不是 true';
      case AnnouncementGateReason.outsideWindow:
        return '不会弹：不在 startAt / endAt 生效窗口内';
      case AnnouncementGateReason.versionMismatch:
        return '不会弹：与当前版本 $communityVersion 的 minVersion / maxVersion 不匹配';
      case AnnouncementGateReason.alreadySeen:
        return '不会弹：该 id 已读过（once=true，可到管理工具里重置已读记录）';
      case AnnouncementGateReason.willShow:
        return '会弹';
    }
  }

  void _openManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsDeveloperAnnouncementManagerPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devSectionAnnouncement)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          if (_busy) const LinearProgressIndicator(),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_outlined, size: 26),
                  title: Text(l10n.devProbeSources),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _probeSources,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, size: 26),
                  title: Text(l10n.devTestPopup),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _testPopup,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, size: 26),
                  title: Text(l10n.devManager),
                  subtitle: Text(
                    l10n.devManagerDesc,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _openManager,
                ),
              ],
            ),
          ),
          if (_probes.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in _probes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${p.status ?? '-'}] ${p.elapsedMs}ms  '
                              '${p.usable ? (p.wouldNotify ? '弹 id=${p.announcement!.id}（${p.announcement!.level.name}）' : '可用但未开启') : '不可用：${p.error}'}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: p.wouldNotify
                                    ? AppColors.accentSuccess
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            SelectableText(p.url, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _result,
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

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
/// - 测试拉取公告：逐个源看 HTTP/耗时/内容，并**标出最终采用哪一条**
///   （判决与生产逻辑共用 [selectNewestIndex]，避免把逐源结果误读成最终结果）；
/// - 自定义 URL 探测：在**自己的网络**上试候选镜像（statically / githack / 自建反代…）；
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
  int? _winnerIndex;
  String _result = '';

  final TextEditingController _customCtrl = TextEditingController();
  AnnouncementSourceProbe? _customResult;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

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

  String _host(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  Future<void> _probeSources() => _run(() async {
        final probes = await probeAnnouncementSources();
        // 与生产逻辑同一套判决：优先 updatedAt 最新，其次源顺序。
        final winner =
            selectNewestIndex(probes.map((p) => p.toFetch()).toList());
        if (!mounted) return;
        setState(() {
          _probes = probes;
          _winnerIndex = winner < 0 ? null : winner;
        });
        final usable = probes.where((p) => p.usable).length;
        if (winner < 0) {
          _toast('探测完成：$usable/${probes.length} 条可用，但没有可用源');
          return;
        }
        final w = probes[winner];
        _toast('探测完成：$usable/${probes.length} 条可用；'
            '最终采用 ${_host(w.url)}'
            '${w.announcement == null ? '（enabled != true）' : ' · id=${w.announcement!.id}'}');
      });

  Future<void> _probeCustom() => _run(() async {
        final url = _customCtrl.text.trim();
        if (url.isEmpty) {
          _toast('请先填 URL');
          return;
        }
        final p = await probeAnnouncementSource(url);
        if (!mounted) return;
        setState(() => _customResult = p);
        if (!p.usable) {
          _toast('不可用：${p.status ?? '-'} ${p.error ?? ''}');
          return;
        }
        final a = p.announcement;
        _toast(a == null
            ? '可用（合法 JSON），但 enabled != true'
            : '可用：id=${a.id} level=${a.level.name} updatedAt=${a.updatedAt?.toIso8601String() ?? '—'}');
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
                  leading:
                      const Icon(Icons.notifications_active_outlined, size: 26),
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
                    Text(
                      _winnerIndex == null
                          ? '${l10n.devFinalChoice}：—（没有可用源）'
                          : '${l10n.devFinalChoice}：'
                              '${_host(_probes[_winnerIndex!].url)}'
                              '${_probes[_winnerIndex!].announcement == null ? '（enabled != true）' : ' · id=${_probes[_winnerIndex!].announcement!.id}'}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < _probes.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '[${_probes[i].status ?? '-'}] ${_probes[i].elapsedMs}ms  '
                              '${_probes[i].usable ? (_probes[i].wouldNotify ? '弹 id=${_probes[i].announcement!.id}（${_probes[i].announcement!.level.name}）' : '可用但未开启') : '不可用：${_probes[i].error}'}'
                              '${i == _winnerIndex ? '  ← ${l10n.devWinnerTag}' : ''}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: i == _winnerIndex
                                    ? AppColors.accentSuccess
                                    : scheme.onSurfaceVariant,
                                fontWeight: i == _winnerIndex
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            Text(
                              'updatedAt: ${_probes[i].updatedAt?.toIso8601String() ?? '—'}',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            SelectableText(_probes[i].url,
                                style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.devCustomProbe, style: textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.devCustomProbeDesc,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _customCtrl,
                    decoration: const InputDecoration(
                      hintText: 'https://…/announcement.json',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _probeCustom,
                      icon: const Icon(Icons.travel_explore, size: 18),
                      label: Text(l10n.devProbe),
                    ),
                  ),
                  if (_customResult != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '[${_customResult!.status ?? '-'}] ${_customResult!.elapsedMs}ms  '
                      '${_customResult!.usable ? (_customResult!.announcement == null ? '可用但未开启' : '可用 id=${_customResult!.announcement!.id}（${_customResult!.announcement!.level.name}）') : '不可用：${_customResult!.error}'}',
                      style: textTheme.bodySmall,
                    ),
                    Text(
                      'updatedAt: ${_customResult!.updatedAt?.toIso8601String() ?? '—'}',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _result,
                style:
                    textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

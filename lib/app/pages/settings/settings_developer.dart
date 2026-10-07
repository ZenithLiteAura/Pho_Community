import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/announcement_dev_tools.dart';
import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/state/developer_mode.dart';
import 'package:img_syncer/app/state/update_checker.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/announcement_dialog.dart';
import 'package:img_syncer/app/widgets/liquid_glass_toast.dart';
import 'package:img_syncer/app/widgets/startup_notice_dialog.dart';
import 'package:img_syncer/app/widgets/update_dialog.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 开发者选项（隐藏页）：应用信息 → 连续点击图标 7 次 → 输入密码进入。
///
/// 这里放的都是**只有维护者会用**的东西：逐个源测试公告拉取、直接推送公告到仓库、
/// 重置已读记录、强制复现弹窗、检查更新测试与诊断信息。
class SettingsDeveloperPage extends StatefulWidget {
  const SettingsDeveloperPage({Key? key}) : super(key: key);

  @override
  State<SettingsDeveloperPage> createState() => _SettingsDeveloperPageState();
}

class _SettingsDeveloperPageState extends State<SettingsDeveloperPage> {
  bool _busy = false;
  List<AnnouncementSourceProbe> _probes = const [];
  String _diagnostics = '';
  String _result = '';

  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _titleZhCtrl = TextEditingController();
  final TextEditingController _titleEnCtrl = TextEditingController();
  final TextEditingController _bodyZhCtrl = TextEditingController();
  final TextEditingController _bodyEnCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  String _level = 'info';

  @override
  void initState() {
    super.initState();
    _idCtrl.text = 'notice-${DateTime.now().year}-';
    readDevGithubToken().then((t) {
      if (!mounted) return;
      setState(() => _tokenCtrl.text = t);
    });
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _idCtrl.dispose();
    _titleZhCtrl.dispose();
    _titleEnCtrl.dispose();
    _bodyZhCtrl.dispose();
    _bodyEnCtrl.dispose();
    _urlCtrl.dispose();
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

  String _buildJson() => buildAnnouncementJson(
        id: _idCtrl.text,
        level: _level,
        titleZh: _titleZhCtrl.text,
        titleEn: _titleEnCtrl.text,
        bodyZh: _bodyZhCtrl.text,
        bodyEn: _bodyEnCtrl.text,
        url: _urlCtrl.text,
      );

  // ── 公告工具 ─────────────────────────────────────────────
  Future<void> _probeSources() => _run(() async {
        final probes = await probeAnnouncementSources();
        if (!mounted) return;
        setState(() => _probes = probes);
        final usable = probes.where((p) => p.usable).length;
        final fresh = probes.where((p) => p.wouldNotify).length;
        _toast('探测完成：可用 $usable/${probes.length} 条，其中 $fresh 条会弹公告');
      });

  Future<void> _previewAnnouncement() => _run(() async {
        final parsed = Announcement.parse(_buildJson());
        if (parsed == null) {
          _toast('表单内容不完整：id 与标题/正文至少要填一个');
          return;
        }
        await showAnnouncementDialog(context, parsed);
      });

  Future<void> _resetSeen() => _run(() async {
        await clearSeenAnnouncementIds();
        _toast('已清空公告已读记录');
      });

  Future<void> _restoreStartupNotice() => _run(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(startupNoticePrefKey, false);
        _toast('下次启动将再次显示版权弹窗');
      });

  Future<void> _showStartupNoticeNow() => _run(() async {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const StartupNoticeDialog(),
        );
      });

  // ── 发布公告 ─────────────────────────────────────────────
  Future<void> _copyJson() => _run(() async {
        await Clipboard.setData(ClipboardData(text: _buildJson()));
        _toast('公告 JSON 已复制到剪贴板');
      });

  Future<void> _publish() => _run(() async {
        await saveDevGithubToken(_tokenCtrl.text);
        final r = await publishAnnouncement(
          token: _tokenCtrl.text,
          jsonText: _buildJson(),
        );
        _toast(r.ok ? '发布成功：${r.message}' : '发布失败：${r.message}');
      });

  Future<void> _disableAnnouncement() => _run(() async {
        await saveDevGithubToken(_tokenCtrl.text);
        final r = await publishAnnouncement(
          token: _tokenCtrl.text,
          jsonText: buildDisabledAnnouncementJson(id: _idCtrl.text),
          commitMessage: 'docs: 下线应用内公告',
        );
        _toast(r.ok ? '已下线公告：${r.message}' : '下线失败：${r.message}');
      });

  // ── 更新检查 ─────────────────────────────────────────────
  Future<void> _testUpdateCheck() => _run(() async {
        final r = await checkForUpdate();
        if (!r.ok) {
          _toast('检查失败（${r.error}）');
          return;
        }
        if (!r.hasUpdate) {
          _toast('已是最新（当前 $communityVersion）');
          return;
        }
        _toast('发现新版本 ${r.release!.version}，弹窗预览中');
        if (!mounted) return;
        await showUpdateAvailableDialog(context, r.release!);
      });

  Future<void> _openReleases() => _run(() async {
        try {
          await launchUrl(Uri.parse(releasesPageUrl),
              mode: LaunchMode.externalApplication);
        } catch (_) {
          _toast('无法打开浏览器');
        }
      });

  // ── 诊断 ─────────────────────────────────────────────────
  Future<void> _collectDiagnostics() => _run(() async {
        final probes = _probes.isEmpty
            ? await probeAnnouncementSources()
            : _probes;
        final prefs = await SharedPreferences.getInstance();
        final text = buildDiagnosticsText(
          probes: probes,
          seenIds: await readSeenAnnouncementIds(),
          startupNoticeDisabled:
              prefs.getBool(startupNoticePrefKey) ?? false,
          updateCheckDisabled:
              prefs.getBool(autoUpdateCheckPrefKey) ?? false,
          announcementCheckDisabled:
              prefs.getBool(announcementCheckPrefKey) ?? false,
        );
        if (!mounted) return;
        setState(() {
          _probes = probes;
          _diagnostics = text;
        });
        await Clipboard.setData(ClipboardData(text: text));
        _toast('诊断信息已生成并复制');
      });

  Future<void> _clearAllPrefs() => _run(() async {
        final l10n = AppLocalizations.of(context)!;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.devClearAllPrefs),
            content: Text(l10n.devConfirmClear),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.devPasswordConfirm),
              ),
            ],
          ),
        );
        if (ok != true) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        _toast(l10n.devCleared);
      });

  Future<void> _lockAgain() => _run(() async {
        await setDeveloperModeUnlocked(false);
        if (!mounted) return;
        Navigator.of(context).pop();
      });

  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devOptions)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          if (_busy) const LinearProgressIndicator(),
          _section(context, l10n.devSectionAnnouncement),
          Card(
            child: Column(
              children: [
                _tile(context, Icons.download_outlined, l10n.devProbeSources,
                    _probeSources),
                const Divider(height: 1),
                _tile(context, Icons.preview_outlined,
                    l10n.devPreviewAnnouncement, _previewAnnouncement),
                const Divider(height: 1),
                _tile(context, Icons.restart_alt, l10n.devResetSeen, _resetSeen),
                const Divider(height: 1),
                _tile(context, Icons.copyright_outlined,
                    l10n.devShowStartupNoticeNow, _showStartupNoticeNow),
                const Divider(height: 1),
                _tile(context, Icons.visibility_outlined,
                    l10n.devForceStartupNotice, _restoreStartupNotice),
              ],
            ),
          ),
          if (_probes.isNotEmpty) _probeResults(context, textTheme, scheme),
          _section(context, l10n.devSectionPublish),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: true,
                    onChanged: (v) => saveDevGithubToken(v),
                    decoration: InputDecoration(
                      labelText: l10n.devGithubToken,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _idCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.devAnnouncementId,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _level,
                    decoration: InputDecoration(
                      labelText: l10n.devLevel,
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'info', child: Text('info')),
                      DropdownMenuItem(
                          value: 'warning', child: Text('warning')),
                      DropdownMenuItem(
                          value: 'critical', child: Text('critical')),
                    ],
                    onChanged: (v) => setState(() => _level = v ?? 'info'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _titleZhCtrl,
                    decoration: const InputDecoration(
                      labelText: '标题（中）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _titleEnCtrl,
                    decoration: const InputDecoration(
                      labelText: '标题（英）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _bodyZhCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '正文（中）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _bodyEnCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '正文（英）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: '链接（可选）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _copyJson,
                        icon: const Icon(Icons.copy_all, size: 18),
                        label: Text(l10n.devGenerateOnly),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: _busy ? null : _publish,
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(l10n.devPublish),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _disableAnnouncement,
                      icon: const Icon(Icons.block, size: 18),
                      label: Text(l10n.devDisableAnnouncement),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _section(context, l10n.devSectionUpdate),
          Card(
            child: Column(
              children: [
                _tile(context, Icons.system_update_alt_outlined,
                    l10n.devTestUpdateCheck, _testUpdateCheck),
                const Divider(height: 1),
                _tile(context, Icons.open_in_new, l10n.devOpenReleases,
                    _openReleases),
              ],
            ),
          ),
          _section(context, l10n.devSectionDiagnostics),
          Card(
            child: Column(
              children: [
                _tile(context, Icons.bug_report_outlined,
                    l10n.devCollectDiagnostics, _collectDiagnostics),
                if (_diagnostics.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: SelectableText(
                      _diagnostics,
                      style: textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          _section(context, l10n.devSectionDanger),
          Card(
            child: Column(
              children: [
                _tile(context, Icons.delete_forever_outlined,
                    l10n.devClearAllPrefs, _clearAllPrefs, danger: true),
                const Divider(height: 1),
                _tile(context, Icons.lock_outline, l10n.devLockAgain, _lockAgain),
              ],
            ),
          ),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                _result,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _probeResults(
      BuildContext context, TextTheme textTheme, ColorScheme scheme) {
    return Card(
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
    );
  }

  Widget _section(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      Future<void> Function() onTap,
      {bool danger = false}) {
    return ListTile(
      leading: Icon(
        icon,
        size: 26,
        color: danger ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(
        title,
        style: danger
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _busy ? null : () => onTap(),
    );
  }
}

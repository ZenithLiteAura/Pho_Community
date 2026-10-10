import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:img_syncer/app/pages/settings/settings_developer_announcement.dart';
import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/announcement_dev_tools.dart';
import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/state/developer_mode.dart';
import 'package:img_syncer/app/state/update_checker.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/liquid_glass_toast.dart';
import 'package:img_syncer/app/widgets/startup_notice_dialog.dart';
import 'package:img_syncer/app/widgets/update_dialog.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 开发者选项（隐藏页）：应用信息 → 连续点击图标 7 次 → 输入密码进入。
///
/// 这里是**总入口**，只放分组与入口；具体工具都在各自的子页里：
/// - 公告 → [SettingsDeveloperAnnouncementPage]（测试拉取 / 测试弹窗 / 公告管理工具）
/// - 启动弹窗、更新检查、诊断、危险操作留在本页。
class SettingsDeveloperPage extends StatefulWidget {
  const SettingsDeveloperPage({Key? key}) : super(key: key);

  @override
  State<SettingsDeveloperPage> createState() => _SettingsDeveloperPageState();
}

class _SettingsDeveloperPageState extends State<SettingsDeveloperPage> {
  bool _busy = false;
  String _diagnostics = '';
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

  void _openAnnouncement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsDeveloperAnnouncementPage(),
      ),
    );
  }

  // ── 启动弹窗 ───────────────────────────────────────────
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

  // ── 更新检查 ───────────────────────────────────────────
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

  // ── 诊断 ───────────────────────────────────────────────
  Future<void> _collectDiagnostics() => _run(() async {
        final probes = await probeAnnouncementSources();
        final prefs = await SharedPreferences.getInstance();
        final text = buildDiagnosticsText(
          probes: probes,
          seenIds: await readSeenAnnouncementIds(),
          startupNoticeDisabled:
              prefs.getBool(startupNoticePrefKey) ?? false,
          updateCheckDisabled:
              prefs.getBool(autoUpdateCheckPrefKey) ?? false,
        );
        if (!mounted) return;
        setState(() => _diagnostics = text);
        await Clipboard.setData(ClipboardData(text: text));
        _toast('诊断信息已生成并复制');
      });

  // ── 危险操作 ───────────────────────────────────────────
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

          // ── 公告（一级标题 + 入口）──
          _section(context, l10n.devSectionAnnouncement),
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined, size: 26),
              title: Text(l10n.devSectionAnnouncement),
              subtitle: Text(
                l10n.devAnnouncementPageDesc,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _openAnnouncement,
            ),
          ),

          _section(context, l10n.devSectionStartupNotice),
          Card(
            child: Column(
              children: [
                _tile(context, Icons.copyright_outlined,
                    l10n.devShowStartupNoticeNow, _showStartupNoticeNow),
                const Divider(height: 1),
                _tile(context, Icons.visibility_outlined,
                    l10n.devForceStartupNotice, _restoreStartupNotice),
              ],
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

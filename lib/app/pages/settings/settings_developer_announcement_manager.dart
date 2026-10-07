import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/announcement_dev_tools.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/app/widgets/liquid_glass_toast.dart';
import 'package:img_syncer/app/widgets/miuix_dropdown.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 开发者选项 → 公告 → 公告管理工具。
///
/// 这里是**写操作**集中地：查看/复制云端当前内容、翻历史版本并回滚或载入表单、
/// 发布新公告、生成 JSON、下线公告、重置已读记录。
/// Token 只存在本机（SharedPreferences），不进源码、不进仓库。
class SettingsDeveloperAnnouncementManagerPage extends StatefulWidget {
  const SettingsDeveloperAnnouncementManagerPage({Key? key}) : super(key: key);

  @override
  State<SettingsDeveloperAnnouncementManagerPage> createState() =>
      _SettingsDeveloperAnnouncementManagerPageState();
}

class _SettingsDeveloperAnnouncementManagerPageState
    extends State<SettingsDeveloperAnnouncementManagerPage> {
  bool _busy = false;
  String _result = '';
  String? _currentContent;
  List<AnnouncementRevision> _history = const [];
  String _historyMessage = '';

  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _idCtrl = TextEditingController();
  final TextEditingController _titleZhCtrl = TextEditingController();
  final TextEditingController _titleEnCtrl = TextEditingController();
  final TextEditingController _bodyZhCtrl = TextEditingController();
  final TextEditingController _bodyEnCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  String _level = 'info';

  /// 动作菜单的锚点：用按下位置，让 MIUIX 菜单贴着手指那坨冒出来。
  Offset? _menuAnchor;

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

  bool get _hasToken => _tokenCtrl.text.trim().isNotEmpty;

  String _buildJson() => buildAnnouncementJson(
        id: _idCtrl.text,
        level: _level,
        titleZh: _titleZhCtrl.text,
        titleEn: _titleEnCtrl.text,
        bodyZh: _bodyZhCtrl.text,
        bodyEn: _bodyEnCtrl.text,
        url: _urlCtrl.text,
      );

  // ── 读 ────────────────────────────────────────────────
  Future<void> _loadCurrent() => _run(() async {
        if (!_hasToken) {
          _toast('请先填 GitHub Token');
          return;
        }
        final text = await fetchAnnouncementContent(token: _tokenCtrl.text);
        if (!mounted) return;
        if (text == null) {
          _toast('读取云端内容失败');
          return;
        }
        setState(() => _currentContent = text);
        _toast('已读取云端当前内容');
      });

  Future<void> _loadHistory() => _run(() async {
        if (!_hasToken) {
          _toast('请先填 GitHub Token');
          return;
        }
        final r = await fetchAnnouncementHistory(token: _tokenCtrl.text);
        if (!mounted) return;
        setState(() {
          _history = r.revisions;
          _historyMessage = r.message;
        });
        _toast(r.ok ? '已读取历史：${r.message}' : '读取历史失败：${r.message}');
      });

  /// 历史行的动作菜单：与下拉共用同一套 MIUIX 锚定面板。
  Future<void> _openHistoryActions(AnnouncementRevision rev) async {
    final l10n = AppLocalizations.of(context)!;
    final at = _menuAnchor ?? Offset.zero;
    final picked = await showMiuixActionMenu(
      context: context,
      title: rev.shortSha,
      anchorRect: Rect.fromLTWH(at.dx - 18, at.dy - 44, 36, 36),
      items: [
        MiuixActionItem(
          label: l10n.devLoadIntoForm,
          summary: '填入下方表单',
          icon: Icons.edit_note,
        ),
        MiuixActionItem(
          label: l10n.devRestore,
          summary: '重新提交为最新',
          icon: Icons.history,
        ),
      ],
    );
    if (!mounted || picked == null) return;
    if (picked == 0) {
      await _loadIntoForm(rev);
    } else if (picked == 1) {
      await _restore(rev);
    }
  }

  Future<void> _loadIntoForm(AnnouncementRevision rev) => _run(() async {
        final text =
            await fetchAnnouncementContent(token: _tokenCtrl.text, ref: rev.sha);
        if (text == null) {
          _toast('读取 ${rev.shortSha} 的内容失败');
          return;
        }
        Object? decoded;
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          _toast('该版本不是合法 JSON');
          return;
        }
        if (decoded is! Map) {
          _toast('该版本不是 JSON 对象');
          return;
        }
        final map = Map<String, dynamic>.from(decoded);
        String pick(Object? v) => v?.toString() ?? '';
        String pickLocalized(Object? v, String key) {
          if (v is Map) return pick(v[key]);
          return pick(v);
        }

        setState(() {
          _idCtrl.text = pick(map['id']);
          _level = pick(map['level']).isEmpty ? 'info' : pick(map['level']);
          _titleZhCtrl.text = pickLocalized(map['title'], 'zh');
          _titleEnCtrl.text = pickLocalized(map['title'], 'en');
          _bodyZhCtrl.text = pickLocalized(map['body'], 'zh');
          _bodyEnCtrl.text = pickLocalized(map['body'], 'en');
          _urlCtrl.text = pick(map['url']);
        });
        _toast('已载入 ${rev.shortSha} 到表单（注意：要换 id 才会再次弹出）');
      });

  Future<void> _restore(AnnouncementRevision rev) => _run(() async {
        final ok = await _confirm('把 ${rev.shortSha}「${rev.message}」重新提交为最新？');
        if (!ok) return;
        final r = await restoreAnnouncementRevision(
            token: _tokenCtrl.text, sha: rev.sha);
        _toast(r.ok ? '已回滚：${r.message}' : '回滚失败：${r.message}');
        if (r.ok) {
          await _loadHistory();
        }
      });

  // ── 写 ────────────────────────────────────────────────
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
        if (r.ok) {
          await _loadHistory();
        }
      });

  Future<void> _disableAnnouncement() => _run(() async {
        final ok = await _confirm('确认下线公告（把 enabled 写成 false）？');
        if (!ok) return;
        await saveDevGithubToken(_tokenCtrl.text);
        final r = await publishAnnouncement(
          token: _tokenCtrl.text,
          jsonText: buildDisabledAnnouncementJson(id: _idCtrl.text),
          commitMessage: 'docs: 下线应用内公告',
        );
        _toast(r.ok ? '已下线公告：${r.message}' : '下线失败：${r.message}');
        if (r.ok) {
          await _loadHistory();
        }
      });

  Future<void> _resetSeen() => _run(() async {
        await clearSeenAnnouncementIds();
        _toast('已清空公告已读记录');
      });

  Future<bool> _confirm(String message) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
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
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devManagerTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _tokenCtrl,
              obscureText: true,
              onChanged: (v) {
                saveDevGithubToken(v);
                setState(() {});
              },
              decoration: InputDecoration(
                labelText: l10n.devGithubToken,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          _section(context, l10n.devSectionRead),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined, size: 26),
                  title: Text(l10n.devCurrentContent),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _loadCurrent,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history, size: 26),
                  title: Text(l10n.devHistory),
                  subtitle: Text(
                    _historyMessage.isEmpty
                        ? l10n.devHistoryHint
                        : _historyMessage,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _loadHistory,
                ),
              ],
            ),
          ),
          if (_currentContent != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(l10n.devCurrentContent,
                              style: textTheme.labelSmall),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_all, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: _currentContent!));
                            _toast('已复制云端内容');
                          },
                        ),
                      ],
                    ),
                    SelectableText(_currentContent!, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          if (_history.isNotEmpty)
            Card(
              child: Column(
                children: [
                  for (final rev in _history) ...[
                    ListTile(
                      dense: true,
                      title: Text('${rev.shortSha}  ${rev.message}',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${rev.date ?? ''}  ${rev.author ?? ''}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      trailing: GestureDetector(
                        onTapDown: (d) => _menuAnchor = d.globalPosition,
                        onTap: () => _openHistoryActions(rev),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.more_horiz),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          _section(context, l10n.devSectionPublish),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _idCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.devAnnouncementId,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MiuixDropdownField<String>(
                    label: l10n.devLevel,
                    value: _level,
                    items: const [
                      MiuixDropdownItem(
                          value: 'info', label: 'info', summary: '普通通知'),
                      MiuixDropdownItem(
                          value: 'warning', label: 'warning', summary: '提醒'),
                      MiuixDropdownItem(
                          value: 'critical', label: 'critical', summary: '强制展示'),
                    ],
                    onChanged: (v) => setState(() => _level = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _titleZhCtrl,
                    decoration: const InputDecoration(
                        labelText: '标题（中）', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _titleEnCtrl,
                    decoration: const InputDecoration(
                        labelText: '标题（英）', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _bodyZhCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: '正文（中）', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _bodyEnCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: '正文（英）', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                        labelText: '链接（可选）', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _copyJson,
                        icon: const Icon(Icons.copy_all, size: 18),
                        label: Text(l10n.devGenerateOnly),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _publish,
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(l10n.devPublish),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _disableAnnouncement,
                        icon: const Icon(Icons.block, size: 18),
                        label: Text(l10n.devDisableAnnouncement),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _resetSeen,
                        icon: const Icon(Icons.restart_alt, size: 18),
                        label: Text(l10n.devResetSeen),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.devManagerNote,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (_result.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(_result,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
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
}

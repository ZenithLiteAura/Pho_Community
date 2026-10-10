import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 启动时检查应用内公告。
///
/// **没有开关，固定开启** —— 公告是与用户沟通的渠道，必须能到达。
/// 全程静默失败（网络不通、源 404、JSON 非法都直接返回）；
/// 只有同时满足「enabled=true + 生效窗口内 + 版本区间内 + 该 id 未读」时才弹窗。
Future<void> autoCheckAnnouncementAndNotify(BuildContext context) async {
  if (!context.mounted) return;

  final announcement = await fetchAnnouncement();
  if (announcement == null || !context.mounted) return;
  if (!announcement.matches(
      now: DateTime.now(), appVersion: communityVersion)) {
    return;
  }
  if (announcement.once && await _isSeen(announcement.id)) return;
  if (!context.mounted) return;

  await showAnnouncementDialog(context, announcement);
  if (announcement.once) await _markSeen(announcement.id);
}

/// 弹出公告。
///
/// [Announcement.dismissible] 为 false（critical 级别）时，点遮罩无效，
/// 只能通过弹窗里的按钮确认关闭。
Future<void> showAnnouncementDialog(
    BuildContext context, Announcement announcement) {
  return showDialog<void>(
    context: context,
    barrierDismissible: announcement.dismissible,
    builder: (_) => AnnouncementDialog(announcement: announcement),
  );
}

Future<bool> _isSeen(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(announcementSeenIdsKey) ?? '';
    return raw.split(',').map((e) => e.trim()).contains(id);
  } catch (_) {
    return false;
  }
}

Future<void> _markSeen(String id) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(announcementSeenIdsKey) ?? '';
    final ids = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.contains(id)) return;
    ids.add(id);
    // 只保留最近 30 条，避免键值无限增长。
    final keep = ids.length > 30 ? ids.sublist(ids.length - 30) : ids;
    await prefs.setString(announcementSeenIdsKey, keep.join(','));
  } catch (_) {
    // 写入失败只影响「去重」，不影响本次展示。
  }
}

/// 应用内公告弹窗。
class AnnouncementDialog extends StatelessWidget {
  const AnnouncementDialog({Key? key, required this.announcement})
      : super(key: key);

  final Announcement announcement;

  bool get _critical => announcement.level == AnnouncementLevel.critical;

  Future<void> _openUrl() async {
    final url = announcement.url;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // 打不开浏览器时忽略：链接在弹窗中可选中复制。
    }
  }

  IconData get _icon {
    switch (announcement.level) {
      case AnnouncementLevel.critical:
        return Icons.error_outline;
      case AnnouncementLevel.warning:
        return Icons.warning_amber_rounded;
      case AnnouncementLevel.info:
        return Icons.campaign_outlined;
    }
  }

  Color _color(ColorScheme scheme) {
    switch (announcement.level) {
      case AnnouncementLevel.critical:
        return scheme.error;
      case AnnouncementLevel.warning:
        return AppColors.accentWarning;
      case AnnouncementLevel.info:
        return scheme.primary;
    }
  }

  String _levelLabel(AppLocalizations l10n) {
    switch (announcement.level) {
      case AnnouncementLevel.critical:
        return l10n.announcementLevelCritical;
      case AnnouncementLevel.warning:
        return l10n.announcementLevelWarning;
      case AnnouncementLevel.info:
        return l10n.announcementLevelInfo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final title = announcement.title.resolve(locale);
    final body = announcement.body.resolve(locale);
    final color = _color(scheme);
    final url = announcement.url;

    return PopScope(
      // critical 公告不允许用返回键/返回手势关掉。
      canPop: announcement.dismissible,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(_icon, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(title.isEmpty ? l10n.announcementTitle : title),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _levelLabel(l10n),
                style: textTheme.labelSmall?.copyWith(
                  color: color,
                  letterSpacing: 0.6,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(body, style: textTheme.bodyMedium),
              ],
              if (url != null) ...[
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  url,
                  style: textTheme.bodySmall?.copyWith(color: scheme.primary),
                ),
              ],
              if (_critical) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.announcementCriticalHint,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (url != null)
            FilledButton(
              onPressed: _openUrl,
              child: Text(l10n.announcementGoTo),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.announcementOk),
          ),
        ],
      ),
    );
  }
}

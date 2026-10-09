import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/theme/design_tokens.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 启动前弹窗的锁定秒数：倒计时结束前无法关闭。
const int startupNoticeLockSeconds = 10;

/// 进程内是否已经弹过（同一进程只弹一次）。
bool _shownThisLaunch = false;

/// 仅供测试：重置「本次启动已弹过」标记。
@visibleForTesting
void resetStartupNoticeShownForTest() {
  _shownThisLaunch = false;
}

/// 冷启动时调用：若用户未在「设置 → 关于 → 高级设置」中关闭启动前弹窗，
/// 则弹出欢迎与试用提示。
///
/// 行为约定：
/// - 每次**冷启动**都会弹出（除非用户已关闭该开关）；
/// - 同一进程内只弹一次；
/// - 弹窗在 [startupNoticeLockSeconds] 秒内无法关闭（遮罩、返回键、按钮全部屏蔽）。
///
/// SharedPreferences 读取失败时保守按「显示」处理，保证这条提示不会因异常被静默跳过。
Future<void> showStartupNoticeIfNeeded(BuildContext context) async {
  if (_shownThisLaunch) return;
  _shownThisLaunch = true;

  var disabled = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    disabled = prefs.getBool(startupNoticePrefKey) ?? false;
  } catch (_) {
    disabled = false;
  }
  if (disabled || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const StartupNoticeDialog(),
  );
}

/// 启动欢迎弹窗。
///
/// 内容 = 产品简介 + 发行渠道说明 + 「试用前先备份」的免责声明；
/// 版权与原作者信息统一放在「设置 → 应用信息（关于）」页，弹窗里不再重复，
/// 因此这里也不再需要外链。
class StartupNoticeDialog extends StatefulWidget {
  const StartupNoticeDialog({Key? key}) : super(key: key);

  @override
  State<StartupNoticeDialog> createState() => _StartupNoticeDialogState();
}

class _StartupNoticeDialogState extends State<StartupNoticeDialog> {
  /// 剩余锁定秒数；0 表示可以关闭。
  int _remain = startupNoticeLockSeconds;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remain > 0) {
          _remain--;
        }
      });
      if (_remain <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    // 必须在此取消，否则弹窗销毁后定时器仍会触发 setState。
    _timer?.cancel();
    super.dispose();
  }

  bool get _canClose => _remain <= 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 10 秒锁定期间屏蔽返回键与返回手势；遮罩点击由 barrierDismissible: false 屏蔽。
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.waving_hand_outlined, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(l10n.startupNoticeWelcomeTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.startupNoticeWelcomeBody1, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.startupNoticeWelcomeBody2, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              // 免责声明单独框一下，避免被当成普通正文略过。
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  l10n.startupNoticeWelcomeWarning,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const Divider(height: AppSpacing.lg),
              // 用户此刻正对着这个弹窗，把「不想每次都看到」的关闭方式直接写在这里，
              // 省得他们去猜设置在哪一层。
              Text(
                l10n.startupNoticeHowToDisable,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _canClose
                    ? l10n.startupNoticeCanCloseNow
                    : '$_remain ${l10n.startupNoticeSecondsLeft}',
                style: textTheme.bodySmall?.copyWith(
                  color: _canClose
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            // 倒计时结束前保持禁用：这是「10 秒后才能关闭」的唯一出口。
            onPressed: _canClose ? () => Navigator.of(context).pop() : null,
            child: Text(l10n.startupNoticeClose),
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 开发者选项解锁状态的持久化 key。
const String developerModePrefKey = 'developer_mode_unlocked';

/// 开发者密码的 MD5 摘要（只存摘要：明文既不进源码、也不进仓库）。
const String developerPasswordMd5 = 'd2f645bb929208b1a65bab94d8226596';

/// 需要连续点击图标多少次才弹出密码框。
const int developerUnlockTapCount = 7;

/// 两次点击之间允许的最大间隔；超时则重新计数。
const Duration developerUnlockTapGap = Duration(seconds: 3);

/// 校验开发者密码：把输入做 MD5 后与内置摘要比较（大小写不敏感）。
///
/// 注意：这是**防误触的遮挡**，不是安全边界 —— 客户端校验天然可绕过。
/// 真正需要权限的操作（例如推送公告到 GitHub）依然要有 Token 才能成功。
bool verifyDeveloperPassword(String input) {
  if (input.isEmpty) return false;
  final digest = md5.convert(utf8.encode(input)).toString();
  return digest.toLowerCase() == developerPasswordMd5.toLowerCase();
}

/// 连续点击计数：连续 [developerUnlockTapCount] 次（相邻间隔不超过
/// [developerUnlockTapGap]）返回 true，并自动清零。
class DeveloperTapGate {
  int _count = 0;
  DateTime? _lastTap;

  /// 当前已累计的点击次数（可用于调试展示）。
  int get count => _count;

  bool registerTap([DateTime? now]) {
    final tappedAt = now ?? DateTime.now();
    final last = _lastTap;
    if (last != null && tappedAt.difference(last) > developerUnlockTapGap) {
      _count = 0;
    }
    _lastTap = tappedAt;
    _count++;
    if (_count >= developerUnlockTapCount) {
      reset();
      return true;
    }
    return false;
  }

  void reset() {
    _count = 0;
    _lastTap = null;
  }
}

/// 开发者选项是否已解锁（解锁状态跨启动保留，可在页面内重新锁定）。
Future<bool> isDeveloperModeUnlocked() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(developerModePrefKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> setDeveloperModeUnlocked(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(developerModePrefKey, value);
  } catch (_) {
    // 忽略：失败只影响下次是否仍处于解锁状态。
  }
}

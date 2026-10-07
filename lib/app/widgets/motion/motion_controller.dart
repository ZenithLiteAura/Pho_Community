import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 动效级别。
///
/// - [off]    关：无触点展开、无凝光、无果冻拖拽（仅淡入）
/// - [simple] 简：有触点展开 + 轻量凝光；浮层可下拉关闭，但无晃动形变
/// - [full]   全：触点展开 + 跟随手指的凝光 + 果冻晃动回弹
enum MotionLevel {
  off,
  simple,
  full,
}

/// 动效级别持久化 key。
const String motionLevelPrefKey = 'motion_level';

/// 全局动效控制器：统一管理弹层/浮层的动效强度，并持久化。
///
/// 仿 [DockStyleController] 的既有模式（ChangeNotifier 单例 + SharedPreferences）。
class MotionController extends ChangeNotifier {
  MotionLevel _level = MotionLevel.full;

  MotionLevel get level => _level;

  /// 是否启用触点展开（`off` 时不做）。
  bool get morphEnabled => _level != MotionLevel.off;

  /// 是否绘制凝光层。
  bool get bloomEnabled => _level != MotionLevel.off;

  /// 是否启用果冻晃动形变（仅 `full`）。
  bool get jellyEnabled => _level == MotionLevel.full;

  /// 是否允许下拉关闭浮层。
  bool get dragToDismissEnabled => _level != MotionLevel.off;

  /// 展开动画时长。
  Duration get enterDuration {
    switch (_level) {
      case MotionLevel.off:
        return const Duration(milliseconds: 110);
      case MotionLevel.simple:
        return const Duration(milliseconds: 200);
      case MotionLevel.full:
        return const Duration(milliseconds: 280);
    }
  }

  /// 从 SharedPreferences 恢复上次选择。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(motionLevelPrefKey);
    if (raw == null) return;
    final next = _parse(raw);
    if (next != _level) {
      _level = next;
      notifyListeners();
    }
  }

  /// 设置级别并持久化。
  Future<void> setLevel(MotionLevel level) async {
    if (_level == level) return;
    _level = level;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(motionLevelPrefKey, _serialize(level));
  }

  static MotionLevel _parse(String raw) {
    switch (raw) {
      case 'off':
        return MotionLevel.off;
      case 'simple':
        return MotionLevel.simple;
      default:
        return MotionLevel.full;
    }
  }

  static String _serialize(MotionLevel level) {
    switch (level) {
      case MotionLevel.off:
        return 'off';
      case MotionLevel.simple:
        return 'simple';
      case MotionLevel.full:
        return 'full';
    }
  }
}

/// 全局动效控制器单例。
MotionController motionController = MotionController();
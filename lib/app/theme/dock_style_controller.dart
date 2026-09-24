import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 底部 Dock 视觉风格。
///
/// - [frosted] 磨砂玻璃：背景模糊（BackdropFilter），半透明 surface。
/// - [mica] 云母质感：在磨砂基础上叠加主题色微染色，呈现 Windows 11 mica 风格。
/// - [solid] 纯色：不启用模糊，纯 surface 色块 + 1px 描边。
enum DockStyle {
  frosted,
  mica,
  solid,
}

/// 透明度档位（控制 Dock 背景的可见度/不透明度）。
enum DockOpacity {
  high,   // 90% 不透明（遮罩下完全可见）
  medium, // 75%
  low,    // 60%（背景穿透更强）
}

/// 模糊半径档位（仅 frosted / mica 生效，solid 忽略）。
enum DockBlur {
  light,  // sigma=10
  medium, // sigma=25
  strong, // sigma=40
}

/// Dock 自定义项持久化 key。
const String dockStylePrefKey = 'dock_style';
const String dockOpacityPrefKey = 'dock_opacity';
const String dockBlurPrefKey = 'dock_blur';

/// 全局 Dock 风格控制器：管理底部导航栏的视觉风格、透明度与模糊度。
///
/// 通过 [ChangeNotifier] 驱动 `MaterialApp` / `MyHomePage` 重建，
/// 即时生效（无需重启）；通过 SharedPreferences 持久化。
class DockStyleController extends ChangeNotifier {
  DockStyle _style = DockStyle.frosted;
  DockOpacity _opacity = DockOpacity.medium;
  DockBlur _blur = DockBlur.strong;

  DockStyle get style => _style;
  DockOpacity get opacity => _opacity;
  DockBlur get blur => _blur;

  /// 当前模糊半径（sigma），仅 frosted / mica 生效。
  double get blurSigma {
    if (_blur == DockBlur.light) return 10;
    if (_blur == DockBlur.medium) return 25;
    return 40;
  }

  /// 当前不透明度（0.0 - 1.0）。
  double get opacityValue {
    if (_opacity == DockOpacity.high) return 0.90;
    if (_opacity == DockOpacity.medium) return 0.75;
    return 0.60;
  }

  /// 从 SharedPreferences 恢复上次选择。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var changed = false;

    final styleStr = prefs.getString(dockStylePrefKey);
    if (styleStr != null) {
      DockStyle next;
      if (styleStr == 'mica') {
        next = DockStyle.mica;
      } else if (styleStr == 'solid') {
        next = DockStyle.solid;
      } else {
        next = DockStyle.frosted;
      }
      if (next != _style) {
        _style = next;
        changed = true;
      }
    }

    final opStr = prefs.getString(dockOpacityPrefKey);
    if (opStr != null) {
      DockOpacity next;
      if (opStr == 'high') {
        next = DockOpacity.high;
      } else if (opStr == 'low') {
        next = DockOpacity.low;
      } else {
        next = DockOpacity.medium;
      }
      if (next != _opacity) {
        _opacity = next;
        changed = true;
      }
    }

    final blurStr = prefs.getString(dockBlurPrefKey);
    if (blurStr != null) {
      DockBlur next;
      if (blurStr == 'light') {
        next = DockBlur.light;
      } else if (blurStr == 'medium') {
        next = DockBlur.medium;
      } else {
        next = DockBlur.strong;
      }
      if (next != _blur) {
        _blur = next;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  /// 设置风格并持久化。
  Future<void> setStyle(DockStyle style) async {
    if (_style == style) return;
    _style = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final str = style == DockStyle.mica
        ? 'mica'
        : style == DockStyle.solid
            ? 'solid'
            : 'frosted';
    await prefs.setString(dockStylePrefKey, str);
  }

  /// 设置透明度并持久化。
  Future<void> setOpacity(DockOpacity opacity) async {
    if (_opacity == opacity) return;
    _opacity = opacity;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final str = opacity == DockOpacity.high
        ? 'high'
        : opacity == DockOpacity.low
            ? 'low'
            : 'medium';
    await prefs.setString(dockOpacityPrefKey, str);
  }

  /// 设置模糊半径并持久化。
  Future<void> setBlur(DockBlur blur) async {
    if (_blur == blur) return;
    _blur = blur;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final str = blur == DockBlur.light
        ? 'light'
        : blur == DockBlur.medium
            ? 'medium'
            : 'strong';
    await prefs.setString(dockBlurPrefKey, str);
  }
}

/// 全局 Dock 风格控制器单例。
DockStyleController dockController = DockStyleController();
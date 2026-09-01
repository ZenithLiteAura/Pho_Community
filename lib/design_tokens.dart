/// 应用设计 Token：Fluid Horizon 设计系统 + 原有兼容常量。
///
/// 所有值均为 `static const`，可在 `const` 上下文中使用。
/// 每个类拥有私有构造函数以防止实例化。
///
/// 来源：
/// - [AppColors] Fluid Horizon 色系 + 原有兼容常量
/// - [AppRadius] Fluid Horizon 圆角（squircle）+ M3 兼容常量
/// - [AppSpacing] Fluid Horizon 间距（4px 网格）+ M3 兼容常量
/// - [AppFonts] Fluid Horizon 字体族
library;

import 'package:flutter/material.dart';

/// 应用颜色常量（Fluid Horizon 色系 + 原有兼容常量）。
class AppColors {
  AppColors._();

  // ── Fluid Horizon 主色 ─────────────────────────────
  static const Color primary = Color(0xFF0058BC);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0070EB);
  static const Color onPrimaryContainer = Color(0xFFFEFCFF);
  static const Color surfaceTint = Color(0xFF005BC1);
  static const Color inversePrimary = Color(0xFFADC6FF);

  // ── Fluid Horizon 背景与表面 ───────────────────────
  static const Color surface = Color(0xFFF9F9FE);
  static const Color surfaceDim = Color(0xFFD9DADE);
  static const Color surfaceBright = Color(0xFFF9F9FE);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F3F8);
  static const Color surfaceContainer = Color(0xFFEDEDF2);
  static const Color surfaceContainerHigh = Color(0xFFE8E8ED);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E7);
  static const Color surfaceVariant = Color(0xFFE2E2E7);
  static const Color surfacePrimary = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF2F2F7);
  static const Color surfaceTertiary = Color(0xFFE5E5EA);
  static const Color background = Color(0xFFF9F9FE);
  static const Color inverseSurface = Color(0xFF2E3034);

  // ── Fluid Horizon 文字 ─────────────────────────────
  static const Color onSurface = Color(0xFF1A1C1F);
  static const Color onSurfaceVariant = Color(0xFF414755);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color inverseOnSurface = Color(0xFFF0F0F5);
  static const Color onBackground = Color(0xFF1A1C1F);

  // ── Fluid Horizon 轮廓 ─────────────────────────────
  static const Color outline = Color(0xFF717786);
  static const Color outlineVariant = Color(0xFFC1C6D7);

  // ── 状态色 ─────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color accentSuccess = Color(0xFF34C759);
  static const Color accentWarning = Color(0xFFFFCC00);
  static const Color accentDanger = Color(0xFFFF3B30);

  // ── 辅助色（备用）──────────────────────────────────
  static const Color secondary = Color(0xFF5E5E5E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE1DFDF);
  static const Color onSecondaryContainer = Color(0xFF626262);
  static const Color tertiary = Color(0xFF894D00);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFAC6300);
  static const Color onTertiaryContainer = Color(0xFFFFFBFF);

  // ── 原有兼容常量（保持向后兼容）────────────────────
  static const Color proCrownColor = Color.fromARGB(255, 234, 205, 118);
  static const Color buyPageBackground = Color.fromARGB(255, 0, 163, 133);
  static const Color videoRouteBg = Color.fromARGB(255, 82, 82, 82);
}

/// 深色模式颜色常量（Dark Fluid Horizon 色系）。
///
/// 与 [AppColors] 对称，仅包含深色模式下需要覆盖的值。
/// 深色模式：浅色文字在深色背景上，确保可读性。
class AppColorsDark {
  AppColorsDark._();

  // ── 深色模式表面 ─────────────────────────────────
  static const Color surface = Color(0xFF101014);
  static const Color surfacePrimary = Color(0xFF2C2C2E);
  static const Color surfaceSecondary = Color(0xFF1C1C1E);
  static const Color surfaceTertiary = Color(0xFF3A3A3C);
  static const Color background = Color(0xFF101014);
  static const Color surfaceContainerLowest = Color(0xFF1C1C1E);
  static const Color surfaceContainerLow = Color(0xFF222225);
  static const Color surfaceContainer = Color(0xFF2A2A2D);
  static const Color surfaceContainerHigh = Color(0xFF333336);
  static const Color surfaceContainerHighest = Color(0xFF3C3C3F);
  static const Color surfaceVariant = Color(0xFF3C3C3F);

  // ── 深色模式文字（浅色，确保在深色背景上可读）─────
  static const Color onSurface = Color(0xFFF0F0F5);
  static const Color onSurfaceVariant = Color(0xFFB0B3BA);
  static const Color textSecondary = Color(0xFF8E9196);
  static const Color inverseSurface = Color(0xFFF0F0F5);
  static const Color inverseOnSurface = Color(0xFF1A1C1F);
  static const Color onBackground = Color(0xFFF0F0F5);

  // ── 深色模式轮廓 ─────────────────────────────────
  static const Color outline = Color(0xFF8E9196);
  static const Color outlineVariant = Color(0xFF414755);

  // ── 深色模式辅助色 ─────────────────────────────────
  static const Color secondaryContainer = Color(0xFF404042);
  static const Color onSecondaryContainer = Color(0xFFD0D0D4);
}

/// 圆角常量（Fluid Horizon squircle + M3 兼容）。
class AppRadius {
  AppRadius._();

  static const double extraSmall = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double card = 24.0;
  static const double container = 32.0;
  static const double extraLarge = 28.0;
  static const double buttonFull = 9999.0;
  static const double input = 14.0;
}

/// 间距常量（Fluid Horizon 4px 基准网格 + M3 兼容）。
class AppSpacing {
  AppSpacing._();

  // ── Fluid Horizon 间距 ─────────────────────────────
  static const double base = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double padding = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double gutter = 16.0;
  static const double marginMobile = 16.0;
  static const double marginDesktop = 64.0;

  // ── 原有兼容常量 ──────────────────────────────────
  static const double paddingStandard = 15.0;
  static const double paddingSmall = 10.0;
  static const double paddingLarge = 20.0;
}

/// Fluid Horizon 字体族。
class AppFonts {
  AppFonts._();

  static const String title = 'PlusJakartaSans';
  static const String body = 'Inter';
  static const String mono = 'JetBrains Mono';
}

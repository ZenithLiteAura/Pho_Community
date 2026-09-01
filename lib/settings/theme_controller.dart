import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/theme.dart';

/// 全局主题风格。
enum PhoThemeMode {
  /// 小米 HyperOS 风格：圆角大卡片、分层灰度背景、紧凑布局、小米蓝强调色。
  miuix,

  /// 标准 Material 3（Material You）：动态取色、标准组件、宽松留白。
  material3,
}

/// 明暗模式。
enum PhoDarkMode {
  /// 始终浅色。
  light,

  /// 始终深色。
  dark,

  /// 跟随系统。
  system,
}

/// 主题样式持久化 key。
const String themeStylePrefKey = 'theme_style';

/// 明暗模式持久化 key。
const String themeDarkModePrefKey = 'theme_dark_mode';

/// 全局主题控制器：管理 MIUIX / Material 3 切换与明暗模式，即时生效并持久化。
///
/// - 通过 [ChangeNotifier] 驱动 MaterialApp 重建，切换后全局立即生效、无需重启；
/// - 选择保存在 SharedPreferences（[themeStylePrefKey] / [themeDarkModePrefKey]），
///   下次启动恢复；
/// - 作为全局单例 [themeController] 使用，也可放入 Provider。
class ThemeController extends ChangeNotifier {
  PhoThemeMode _mode = PhoThemeMode.miuix;
  PhoThemeMode get mode => _mode;

  PhoDarkMode _darkMode = PhoDarkMode.light;
  PhoDarkMode get darkMode => _darkMode;

  bool get isMiuix => _mode == PhoThemeMode.miuix;
  bool get isMaterial3 => _mode == PhoThemeMode.material3;

  /// MIUIX 品牌强调色（Fluid Horizon primary blue）。
  static const Color miuixBlue = AppColors.primary;

  /// 从 SharedPreferences 恢复上次选择。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(themeStylePrefKey);
    final next =
        saved == 'material3' ? PhoThemeMode.material3 : PhoThemeMode.miuix;
    final savedDark = prefs.getString(themeDarkModePrefKey);
    PhoDarkMode nextDark;
    if (savedDark == 'dark') {
      nextDark = PhoDarkMode.dark;
    } else if (savedDark == 'system') {
      nextDark = PhoDarkMode.system;
    } else {
      nextDark = PhoDarkMode.light;
    }
    var changed = false;
    if (next != _mode) {
      _mode = next;
      changed = true;
    }
    if (nextDark != _darkMode) {
      _darkMode = nextDark;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// 切换主题风格并持久化。
  Future<void> setMode(PhoThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      themeStylePrefKey,
      mode == PhoThemeMode.material3 ? 'material3' : 'miuix',
    );
  }

  /// 切换明暗模式并持久化。
  Future<void> setDarkMode(PhoDarkMode mode) async {
    if (_darkMode == mode) return;
    _darkMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final saved = mode == PhoDarkMode.dark
        ? 'dark'
        : mode == PhoDarkMode.system
            ? 'system'
            : 'light';
    await prefs.setString(themeDarkModePrefKey, saved);
  }

  /// 依据明暗模式映射 MaterialApp 的 themeMode。
  ThemeMode get themeMode {
    switch (_darkMode) {
      case PhoDarkMode.dark:
        return ThemeMode.dark;
      case PhoDarkMode.system:
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  /// 依据当前模式构建主题。
  ///
  /// [scheme] 是调用方（DynamicColorBuilder）提供的动态取色 ColorScheme；
  /// MIUIX 模式忽略动态取色、改用 Fluid Horizon 色系，Material 3 模式
  /// 则使用传入的动态取色方案。
  ThemeData buildTheme({
    required ColorScheme scheme,
    required Brightness brightness,
  }) {
    if (_mode == PhoThemeMode.miuix) {
      return buildMiuixTheme(
        colorScheme: scheme,
        brightness: brightness,
      );
    }
    return buildThemeData(colorScheme: scheme, brightness: brightness);
  }
}

/// 全局主题控制器单例。
ThemeController themeController = ThemeController();

/// MIUIX（Fluid Horizon 设计系统）主题构建。
///
/// 严格对照 Stitch 设计稿的 CSS token：
/// - 背景 surfaceSecondary #F2F2F7，卡片 surfacePrimary 纯白 squircle 24px
/// - 主色 #0058BC（primary），辅色 #8E8E93（textSecondary）
/// - Plus Jakarta Sans 标题 + Inter 正文
/// - 玻璃导航栏（backdrop-blur）、4px 间距网格
/// - 输入框 surfaceTertiary 背景、无边框、14px 圆角
ThemeData buildMiuixTheme({
  required ColorScheme colorScheme,
  required Brightness brightness,
}) {
  final bool light = brightness == Brightness.light;

  // ── 强制 Fluid Horizon 色系（忽略动态取色）──────────
  // 深色模式使用 AppColorsDark 以确保文字在深色背景上可读
  final dark = !light;
  final cs = ColorScheme(
    brightness: brightness,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: dark ? AppColorsDark.secondaryContainer : AppColors.secondaryContainer,
    onSecondaryContainer: dark ? AppColorsDark.onSecondaryContainer : AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onTertiaryContainer,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: dark ? AppColorsDark.surface : AppColors.surfaceSecondary,
    onSurface: dark ? AppColorsDark.onSurface : AppColors.onSurface,
    onSurfaceVariant: dark ? AppColorsDark.onSurfaceVariant : AppColors.onSurfaceVariant,
    outline: dark ? AppColorsDark.outline : AppColors.outline,
    outlineVariant: dark ? AppColorsDark.outlineVariant : AppColors.outlineVariant,
    inverseSurface: dark ? AppColorsDark.inverseSurface : AppColors.inverseSurface,
    onInverseSurface: dark ? AppColorsDark.inverseOnSurface : AppColors.inverseOnSurface,
    surfaceTint: AppColors.surfaceTint,
    inversePrimary: AppColors.inversePrimary,
    surfaceContainerLowest: dark ? AppColorsDark.surfaceContainerLowest : AppColors.surfaceContainerLowest,
    surfaceContainerLow: dark ? AppColorsDark.surfaceContainerLow : AppColors.surfaceContainerLow,
    surfaceContainer: dark ? AppColorsDark.surfaceContainer : AppColors.surfaceContainer,
    surfaceContainerHigh: dark ? AppColorsDark.surfaceContainerHigh : AppColors.surfaceContainerHigh,
    surfaceContainerHighest: dark ? AppColorsDark.surfaceContainerHighest : AppColors.surfaceContainerHighest,
  );

  // ── Fluid Horizon 字体 ─────────────────────────────
  final miuixTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: AppFonts.title,
      fontSize: 40,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.02,
      height: 48 / 40,
    ),
    headlineLarge: TextStyle(
      fontFamily: AppFonts.title,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.01,
      height: 36 / 28,
    ),
    headlineMedium: TextStyle(
      fontFamily: AppFonts.title,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 32 / 24,
    ),
    headlineSmall: TextStyle(
      fontFamily: AppFonts.title,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 28 / 20,
    ),
    titleLarge: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 24 / 16,
    ),
    titleMedium: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
    ),
    titleSmall: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
    ),
    bodyLarge: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
    ),
    bodyMedium: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
    ),
    bodySmall: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
    ),
    labelLarge: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.05,
      height: 16 / 12,
    ),
    labelMedium: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.05,
      height: 16 / 12,
    ),
    labelSmall: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.05,
      height: 16 / 12,
    ),
  );

  final bg = light ? AppColors.surfaceSecondary : AppColorsDark.background;
  final card = light ? AppColors.surfacePrimary : AppColorsDark.surfacePrimary;
  final cardShadow = light
      ? [BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 4))]
      : <BoxShadow>[];

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: bg,
    textTheme: miuixTextTheme,
    fontFamily: AppFonts.body,

    // ── AppBar：居中粗体标题 + 玻璃背景 ──────────────
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: miuixTextTheme.headlineMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: cs.onSurfaceVariant),
    ),

    // ── 卡片：squircle 24px + 极淡阴影 ────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      color: card,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    ),

    // ── ListTile：紧凑 + 大圆角 ───────────────────────
    listTileTheme: ListTileThemeData(
      iconColor: cs.onSurfaceVariant,
      textColor: cs.onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      titleTextStyle: miuixTextTheme.titleMedium?.copyWith(color: cs.onSurface),
      subtitleTextStyle: miuixTextTheme.bodySmall?.copyWith(color: dark ? AppColorsDark.textSecondary : AppColors.textSecondary),
    ),

    // ── NavigationBar：玻璃背景、4 items ──────────────
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: cs.primary.withValues(alpha: 0.12),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? cs.primary
              : cs.onSurfaceVariant,
          size: 24,
        ),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        miuixTextTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    ),

    // ── Switch：成功绿开 / 表面变体关 ─────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.surfacePrimary
            : cs.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accentSuccess
            : cs.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : cs.outlineVariant,
      ),
    ),

    // ── FilledButton：pill、primary 背景、白色文字 ────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonFull),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        textStyle: miuixTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // ── SegmentedButton：胶囊、选中 primary ────────────
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.transparent,
        selectedBackgroundColor: cs.primary,
        selectedForegroundColor: cs.onPrimary,
        foregroundColor: cs.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.buttonFull),
        ),
        side: BorderSide(color: cs.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        textStyle: miuixTextTheme.labelMedium,
      ),
    ),

    // ── FAB：pill、primary 背景 ───────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.buttonFull),
      ),
    ),

    // ── 输入框：surfaceTertiary 背景、无边框、14px 圆角 ─
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? AppColors.surfaceTertiary : AppColorsDark.surfaceTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      hintStyle: miuixTextTheme.bodyLarge?.copyWith(color: dark ? AppColorsDark.textSecondary : AppColors.textSecondary),
    ),

    // ── Chip：pill ─────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      labelStyle: miuixTextTheme.bodySmall?.copyWith(color: cs.onSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.buttonFull),
      ),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 0),
    ),

    // ── 菜单：squircle、柔和阴影 ──────────────────────
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      elevation: 8,
      shadowColor: Color(0x0D000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(card),
        elevation: WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(Color(0x0D000000)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        textStyle: miuixTextTheme.bodyLarge?.copyWith(color: cs.onSurface),
      ),
    ),

    // ── Divider：30% 透明、极薄 ────────────────────────
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant.withValues(alpha: 0.3),
      thickness: 0.5,
      space: 0.5,
    ),

    // ── TextButton：squircle ───────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
    ),

    // ── Dialog：squircle 大圆角 ────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.container),
      ),
      elevation: 8,
    ),

    // ── SnackBar：浮动 pill ───────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      backgroundColor: cs.inverseSurface,
      contentTextStyle: miuixTextTheme.bodyMedium?.copyWith(
        color: cs.onInverseSurface,
      ),
    ),

    // ── 页面过渡：深色/浅色切换时平滑渐变 ───────────────────
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
    sliderTheme: SliderThemeData(
      activeTrackColor: cs.primary,
      inactiveTrackColor: cs.surfaceContainerHighest,
      thumbColor: cs.primary,
      overlayColor: cs.primary.withValues(alpha: 0.15),
    ),
  );
}

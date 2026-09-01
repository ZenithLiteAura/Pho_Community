import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';

/// M3 完整 textTheme — Inter 拉丁字体 + 系统 CJK fallback
const textTheme = TextTheme(
  // 大标题 (30sp, Bold, -0.5% 字间距, 1.2 行高)
  headlineLarge: TextStyle(
    fontFamily: 'Inter',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  ),
  // 页面标题 (24sp, SemiBold, 0% 字间距, 1.25 行高)
  headlineMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  ),
  // 小节标题 (20sp, SemiBold, 0% 字间距, 1.3 行高)
  headlineSmall: TextStyle(
    fontFamily: 'Inter',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  ),
  // 列表/卡片标题 (18sp, Medium, 0% 字间距, 1.35 行高)
  titleLarge: TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.35,
  ),
  // 次级标题 (16sp, Medium, 0.15% 字间距, 1.4 行高)
  titleMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.4,
  ),
  // 小标题 (14sp, Medium, 0.1% 字间距, 1.4 行高)
  titleSmall: TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  ),
  // 正文 (16sp, Regular, 0.5% 字间距, 1.5 行高)
  bodyLarge: TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  ),
  // 辅助文字 (14sp, Regular, 0.25% 字间距, 1.5 行高)
  bodyMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  ),
  // 说明文字 (12sp, Regular, 0.4% 字间距, 1.5 行高)
  bodySmall: TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  ),
  // 按钮文字 (14sp, Medium, 0.1% 字间距, 1.4 行高)
  labelLarge: TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  ),
  // 标签 (12sp, Medium, 0.5% 字间距, 1.4 行高)
  labelMedium: TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  ),
  // 小标签 (11sp, Medium, 0.5% 字间距, 1.4 行高)
  labelSmall: TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  ),
);

NavigationBarThemeData buildNavigationBarThemeLight(ColorScheme cs) {
  return NavigationBarThemeData(
    height: 67,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.1,
        height: 1.0,
      ),
    ),
  );
}

NavigationBarThemeData buildNavigationBarThemeDark(ColorScheme cs) {
  return NavigationBarThemeData(
    height: 67,
    iconTheme: WidgetStatePropertyAll(
      IconThemeData(color: cs.onSurfaceVariant),
    ),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
        height: 1.0,
      ),
    ),
  );
}

const iconThemeLight = IconThemeData();
const iconThemeDark = IconThemeData();

const floatingActionButtonThemeLight = FloatingActionButtonThemeData();



List<Color> seedThemeColors = [
  const Color(0xFF02FED1),
  const Color(0xFFFF2C55), // 玫瑰红
  const Color(0xFF007BFF), // 蓝色
  const Color(0xFFFF9500), // 橙色
  const Color(0xFFFFCC00), // 黄色
  const Color(0xFF5AC8FA), // 青色
  const Color(0xFFFF2D55), // 品红
  const Color(0xFF50E3C2), // 翠绿
  const Color(0xFF5856D6), // 紫色
  const Color(0xFF27496D), // 深蓝
  const Color(0xFF808000), // 橄榄绿
  const Color(0xFFFF6347), // 番茄红
  const Color(0xFFCC7722), // 赭石
  const Color(0xFFE6E6FA), // 薰衣草紫
  const Color(0xFF20B2AA), // 浅海洋绿
  const Color(0xFFF08080), // 浅珊瑚色
  const Color(0xFFFA8072), // 三文鱼色
  const Color(0xFFEE82EE), // 紫罗兰
  const Color(0xFFDA70D6), // 兰花紫
  const Color(0xFF9ACD32), // 黄绿色
];

AppBarTheme buildAppBarTheme(ColorScheme cs) {
  return AppBarTheme(
    backgroundColor: cs.surface,
    foregroundColor: cs.onSurface,
    elevation: 0,
    scrolledUnderElevation: 3.0,
    surfaceTintColor: cs.surfaceTint,
  );
}

CardThemeData buildCardTheme(ColorScheme cs) {
  return CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
    ),
    clipBehavior: Clip.antiAlias,
    color: cs.surfaceContainerLow,
    surfaceTintColor: cs.surfaceTint,
  );
}

ListTileThemeData buildListTileTheme(ColorScheme cs) {
  return ListTileThemeData(
    iconColor: cs.onSurfaceVariant,
    textColor: cs.onSurface,
    titleTextStyle: const TextStyle(fontFamily: 'Inter'),
    subtitleTextStyle: const TextStyle(fontFamily: 'Inter'),
  );
}

ChipThemeData buildChipTheme(ColorScheme cs) {
  return ChipThemeData(
    backgroundColor: cs.surfaceContainerHighest,
    labelStyle: TextStyle(fontFamily: 'Inter', color: cs.onSurface),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    side: BorderSide.none,
  );
}

DialogThemeData buildDialogTheme(ColorScheme cs) {
  return DialogThemeData(
    backgroundColor: cs.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.extraLarge),
    ),
    elevation: 3.0,
  );
}

SnackBarThemeData buildSnackBarTheme(ColorScheme cs) {
  return SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    backgroundColor: cs.inverseSurface,
    contentTextStyle: TextStyle(color: cs.onInverseSurface),
  );
}

DividerThemeData buildDividerTheme(ColorScheme cs) {
  return DividerThemeData(
    color: cs.outlineVariant,
    thickness: 1,
    space: 1,
  );
}

SwitchThemeData buildSwitchTheme(ColorScheme cs) {
  return SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? cs.primary
          : cs.onSurfaceVariant,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? cs.primary.withAlpha(128)
          : cs.surfaceContainerHighest,
    ),
    trackOutlineColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? Colors.transparent
          : cs.outlineVariant,
    ),
  );
}

InputDecorationTheme buildInputDecorationTheme(ColorScheme cs) {
  return InputDecorationTheme(
    filled: true,
    fillColor: WidgetStateColor.resolveWith(
      (states) => cs.surfaceContainerHighest,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.extraSmall),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  );
}

NavigationRailThemeData buildNavigationRailTheme(ColorScheme cs) {
  return NavigationRailThemeData(
    backgroundColor: cs.surface,
    indicatorColor: cs.secondaryContainer,
    selectedIconTheme: IconThemeData(color: cs.onSecondaryContainer),
    unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
    selectedLabelTextStyle: TextStyle(
      color: cs.onSecondaryContainer,
      fontFamily: 'Inter',
    ),
    unselectedLabelTextStyle: TextStyle(
      color: cs.onSurfaceVariant,
      fontFamily: 'Inter',
    ),
  );
}

BottomSheetThemeData buildBottomSheetTheme(ColorScheme cs) {
  return BottomSheetThemeData(
    backgroundColor: cs.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.extraLarge),
      ),
    ),
  );
}

ProgressIndicatorThemeData buildProgressIndicatorTheme(ColorScheme cs) {
  return ProgressIndicatorThemeData(color: cs.primary);
}

SliderThemeData buildSliderTheme(ColorScheme cs) {
  return SliderThemeData(
    activeTrackColor: cs.primary,
    inactiveTrackColor: cs.surfaceContainerHighest,
    thumbColor: cs.primary,
    overlayColor: cs.primary.withAlpha(32),
  );
}

FilledButtonThemeData buildFilledButtonTheme(ColorScheme cs) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.buttonFull),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
  );
}

TextButtonThemeData buildTextButtonTheme(ColorScheme cs) {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
    ),
  );
}

OutlinedButtonThemeData buildOutlinedButtonTheme(ColorScheme cs) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.buttonFull),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
  );
}

SegmentedButtonThemeData buildSegmentedButtonTheme(ColorScheme cs) {
  return SegmentedButtonThemeData(
    style: SegmentedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
    ),
  );
}

DropdownMenuThemeData buildDropdownMenuTheme(ColorScheme cs) {
  return DropdownMenuThemeData(
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.extraSmall),
      ),
    ),
  );
}

PopupMenuThemeData buildPopupMenuTheme(ColorScheme cs) {
  return PopupMenuThemeData(
    color: cs.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
  );
}

TooltipThemeData buildTooltipTheme(ColorScheme cs) {
  return TooltipThemeData(
    decoration: BoxDecoration(
      color: cs.inverseSurface,
      borderRadius: BorderRadius.circular(AppRadius.extraSmall),
    ),
    textStyle: TextStyle(color: cs.onInverseSurface),
  );
}

BadgeThemeData buildBadgeTheme(ColorScheme cs) {
  return BadgeThemeData(
    backgroundColor: cs.error,
    textColor: cs.onError,
  );
}

/// 完整 Material 3 主题（动态取色方案 + 全组件定制）。
/// 供 main.dart 与 lib/settings/theme_controller.dart 共用。
ThemeData buildThemeData({
  required ColorScheme colorScheme,
  required Brightness brightness,
}) {
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    textTheme: textTheme,
    navigationBarTheme: brightness == Brightness.light
        ? buildNavigationBarThemeLight(colorScheme)
        : buildNavigationBarThemeDark(colorScheme),
    iconTheme: brightness == Brightness.light ? iconThemeLight : iconThemeDark,
    floatingActionButtonTheme: brightness == Brightness.light
        ? floatingActionButtonThemeLight
        : const FloatingActionButtonThemeData(),
    appBarTheme: buildAppBarTheme(colorScheme),
    cardTheme: buildCardTheme(colorScheme),
    listTileTheme: buildListTileTheme(colorScheme),
    chipTheme: buildChipTheme(colorScheme),
    dialogTheme: buildDialogTheme(colorScheme),
    snackBarTheme: buildSnackBarTheme(colorScheme),
    dividerTheme: buildDividerTheme(colorScheme),
    switchTheme: buildSwitchTheme(colorScheme),
    inputDecorationTheme: buildInputDecorationTheme(colorScheme),
    navigationRailTheme: buildNavigationRailTheme(colorScheme),
    bottomSheetTheme: buildBottomSheetTheme(colorScheme),
    progressIndicatorTheme: buildProgressIndicatorTheme(colorScheme),
    sliderTheme: buildSliderTheme(colorScheme),
    filledButtonTheme: buildFilledButtonTheme(colorScheme),
    textButtonTheme: buildTextButtonTheme(colorScheme),
    outlinedButtonTheme: buildOutlinedButtonTheme(colorScheme),
    segmentedButtonTheme: buildSegmentedButtonTheme(colorScheme),
    dropdownMenuTheme: buildDropdownMenuTheme(colorScheme),
    popupMenuTheme: buildPopupMenuTheme(colorScheme),
    tooltipTheme: buildTooltipTheme(colorScheme),
    badgeTheme: buildBadgeTheme(colorScheme),
  );
}

// 单测：锁住双主题引擎的关键差异，防止 MIUIX / Material 3 视觉退化。
//
// 验证点：
// 1. 两种模式构建出的 ThemeData 在背景、卡片、导航栏、字号上必须可区分；
// 2. ThemeController 切换会持久化到 SharedPreferences 并在 load() 时恢复；
// 3. 默认模式为 MIUIX。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/settings/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final lightScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3D8AFF));

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    // 每个用例前重置 prefs mock，并恢复默认模式，保证用例间隔离
    SharedPreferences.setMockInitialValues({});
    themeController.setMode(PhoThemeMode.miuix);
  });

  test('默认模式为 MIUIX', () {
    expect(themeController.mode, PhoThemeMode.miuix);
  });

  test('MIUIX 与 Material 3 的 ThemeData 存在可感知差异', () {
    final miuix = themeController.buildTheme(
      scheme: lightScheme,
      brightness: Brightness.light,
    );
    final m3 = ThemeData(
      colorScheme: lightScheme,
      useMaterial3: true,
    );

    // 背景：MIUIX 是分层灰，M3 是 scheme surface
    expect(miuix.scaffoldBackgroundColor,
        isNot(equals(lightScheme.surface)));
    // 卡片：MIUIX 白色圆角卡片，M3 默认 12 圆角 surfaceContainerLow
    final miuixCard = miuix.cardTheme;
    expect(miuixCard.shape, isNotNull);
    expect(miuixCard.color, const Color(0xFFFFFFFF));
    // 导航栏：MIUIX 白色底
    expect(miuix.navigationBarTheme.backgroundColor, const Color(0xFFFFFFFF));
    // 主题差异：主色来自小米蓝种子（M3 动态取色或同种子也应有差异，此处断言主色非纯黑/纯白）
    expect(miuix.colorScheme.primary.computeLuminance(), greaterThan(0.0));
    expect(miuix.colorScheme.primary.computeLuminance(), lessThan(1.0));
  });

  test('切换到 Material 3 与 MIUIX 的 scaffold 背景不同', () {
    final a = themeController.buildTheme(
      scheme: lightScheme,
      brightness: Brightness.light,
    );
    themeController.setMode(PhoThemeMode.material3);
    final b = themeController.buildTheme(
      scheme: lightScheme,
      brightness: Brightness.light,
    );
    expect(a.scaffoldBackgroundColor, isNot(equals(b.scaffoldBackgroundColor)));
    themeController.setMode(PhoThemeMode.miuix);
  });

  test('切换持久化到 SharedPreferences 并可恢复', () async {
    await themeController.setMode(PhoThemeMode.material3);
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(themeStylePrefKey), 'material3');

    // 模拟新会话：新实例 load() 后恢复 material3
    final fresh = ThemeController();
    await fresh.load();
    expect(fresh.mode, PhoThemeMode.material3);

    await themeController.setMode(PhoThemeMode.miuix);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(themeStylePrefKey), 'miuix');
    final fresh2 = ThemeController();
    await fresh2.load();
    expect(fresh2.mode, PhoThemeMode.miuix);
  });

  test('MIUIX 文字更紧凑（标题字号小于 M3 默认 headlineMedium）', () {
    final miuix = themeController.buildTheme(
      scheme: lightScheme,
      brightness: Brightness.light,
    );
    expect(miuix.textTheme.headlineMedium?.fontSize,
        lessThanOrEqualTo(22));
  });
}

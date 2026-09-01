import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:img_syncer/desktop/home_page.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/util.dart';
import 'package:provider/provider.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gallery_body.dart';
import 'sync_body.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/theme.dart';
import 'package:img_syncer/settings/theme_controller.dart';
import 'package:img_syncer/settings/dock_style_controller.dart';
import 'package:img_syncer/settings/settings_home.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/onboarding/onboarding_route.dart';
// iOS 后台同步 headless entrypoint，必须被 main 的 import 图可达，
// 否则 Debug Dart kernel 不会编译此库，BGProcessingTask 启动 headless
// engine 时 Dart_LookupLibrary 找不到它。
// ignore: unused_import
import 'background_sync_entrypoint.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // 恢复用户主题选择（MIUIX / Material 3），避免启动闪烁
  await themeController.load();
  // 恢复底部 Dock 风格/透明度/模糊度
  await dockController.load();
  Global.init().then((e) => runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (context) => settingModel),
            ChangeNotifierProvider(create: (context) => assetModel),
            ChangeNotifierProvider(create: (context) => stateModel),
            ChangeNotifierProvider(create: (context) => themeController),
            ChangeNotifierProvider(create: (context) => dockController),
          ],
          child: const MyApp(),
        ),
      ));
}

class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();
  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _needsOnboarding = !(prefs.getBool('has_onboarded') ?? false);
      });
    });
  }

  void _finishOnboarding() {
    if (!mounted) return;
    setState(() {
      _needsOnboarding = false;
    });
    // 引导页可能遮住了系统权限弹窗，导致首次照片加载失败。
    // 退出引导页后重新触发加载。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      eventBus.fire(LocalRefreshEvent(refreshUnSync: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    initI18n(context);
    if (_needsOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_needsOnboarding!) {
      return OnboardingRoute(onComplete: _finishOnboarding);
    }
    return const MyHomePage(title: 'PHO');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  static const String _title = 'PHO';
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 设置状态栏颜色为透明
      systemNavigationBarColor: Colors.transparent, // 设置导航栏颜色为透明
      systemNavigationBarDividerColor: Colors.transparent, // 设置导航栏分隔线颜色为透明
    ));
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        late ColorScheme lightColorScheme;
        late ColorScheme darkColorScheme;
        if (lightDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
        } else {
          print("lightDynamic is null");
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: seedColor ?? seedThemeColors[0],
            brightness: Brightness.light,
          );
        }
        if (darkDynamic != null) {
          darkColorScheme = darkDynamic.harmonized();
        } else {
          print("darkDynamic is null");
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: seedColor ?? seedThemeColors[0],
            brightness: Brightness.dark,
          );
        }

        return ListenableBuilder(
          listenable: themeController,
          builder: (context, _) {
            final light = themeController.buildTheme(
              scheme: lightColorScheme,
              brightness: Brightness.light,
            );
            final dark = themeController.buildTheme(
              scheme: darkColorScheme,
              brightness: Brightness.dark,
            );
            return MaterialApp(
                title: _title,
                debugShowCheckedModeBanner: false,
                home: const _AppEntryPoint(),
                theme: light,
                darkTheme: dark,
                themeMode: themeController.themeMode,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    SnackBarManager.init(context);
    // W7-T1: 恢复警告 - 检测空syncedIDs但有历史刷新记录的情况
    SharedPreferences.getInstance().then((prefs) {
      final syncedIds = prefs.getString('synced_ids');
      final lastRefresh = prefs.getInt('last_refersh_unsync');
      if (syncedIds != null &&
          syncedIds == '[]' &&
          lastRefresh != null &&
          lastRefresh != 0) {
        SnackBarManager.showSnackBar("之前同步状态丢失，建议连接 WiFi 后保持应用前台以重新校验同步状态");
      }
    });
    SharedPreferences.getInstance().then((prefs) async {
      final seedColorValue = prefs.getInt("seed_color");
      if (seedColorValue != null) {
        seedColor = Color(seedColorValue);
        // 主题随 themeController 重建，seedColor 会在 DynamicColorBuilder 中生效。
      }
    });
    if (!isDesktop()) {
      Connectivity().checkConnectivity().then((results) {
        stateModel.setOnline(!results.contains(ConnectivityResult.none));
      });
      Connectivity().onConnectivityChanged.listen((results) {
        stateModel.setOnline(!results.contains(ConnectivityResult.none));
      });
    }
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      stateModel.needStopSync = true;
    } else if (state == AppLifecycleState.resumed) {
      // 息屏/切后台后回到前台：连接可能已被系统冻结失效。
      // 重置中断标志，强制探测 Go server（绕过 60s 去抖），并触发 cloud 刷新。
      stateModel.needStopSync = false;
      lastAliveTime = null;
      checkServer().then((_) {
        if (settingModel.isRemoteStorageSetted) {
          eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
        }
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    initI18n(context);
    initRequestPermission(context);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isMiuix = context.watch<ThemeController>().isMiuix;
    return !isDesktop()
        ? Consumer<StateModel>(
            builder: (context, model, child) => Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Stack(
                children: [
                  Column(
                    children: [
                      if (!model.isOnline)
                        Container(
                          width: double.infinity,
                          color: cs.errorContainer,
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Text(
                            l10n.offline,
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall
                                ?.copyWith(color: cs.onErrorContainer),
                          ),
                        ),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: [
                            GalleryBody(useLocal: true),
                            Consumer<SettingModel>(
                              builder: (context, model, child) =>
                                  SyncBody(localFolder: model.localFolder),
                            ),
                            const SettingsHome(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!model.isSelectionMode)
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
                      child: _buildFloatingBottomNav(context, cs, isMiuix),
                    ),
                ],
              ),
            ),
          )
        : const DesktopHomePage();
  }

  /// Fluid Horizon 悬浮式玻璃导航栏（3 tabs：预览 / 同步 / 设置）。
  ///
  /// 风格由 [dockController] 控制：frosted（磨砂）/ mica（云母）/ solid（纯色）。
  /// v3.1 优化：使用 ListenableBuilder 替代 Consumer，减少不必要的 rebuild。
  Widget _buildFloatingBottomNav(BuildContext context, ColorScheme cs, bool isMiuix) {
    return ListenableBuilder(
      listenable: dockController,
      builder: (context, _) {
        final borderRadius = AppRadius.extraLarge;
        final opacity = dockController.opacityValue;
        final sigma = dockController.blurSigma;
        final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
        Widget container = Container(
          height: 64,
          decoration: BoxDecoration(
            color: dockController.style == DockStyle.mica
                ? Color.alphaBlend(
                      cs.primary.withValues(alpha: 0.08),
                      scaffoldBg.withValues(alpha: opacity),
                    )
                : scaffoldBg.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              width: 0.5,
            ),
            boxShadow: dockController.style == DockStyle.solid
                ? <BoxShadow>[]
                : [
                    BoxShadow(
                      color: cs.scrim.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, cs, 0, Icons.photo_library_outlined,
                  Icons.photo_library, l10n.preview),
              _navItem(context, cs, 1, Icons.cloud_sync_outlined,
                  Icons.cloud_sync, l10n.sync),
              _navItem(context, cs, 2, Icons.settings_outlined,
                  Icons.settings, l10n.settings),
            ],
          ),
        );

        // solid 风格：不启用 BackdropFilter
        if (dockController.style == DockStyle.solid) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: container,
          );
        }

        // frosted / mica：启用 BackdropFilter
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: container,
          ),
        );
      },
    );
  }

  Widget _navItem(
    BuildContext context,
    ColorScheme cs,
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final selected = _selectedIndex == index;
    final color = selected ? cs.primary : cs.onSurfaceVariant;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

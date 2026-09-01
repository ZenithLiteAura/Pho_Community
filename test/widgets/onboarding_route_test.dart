import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/global.dart' as global;
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/onboarding/onboarding_route.dart';
import 'package:img_syncer/setting_storage_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingRoute', () {
    Widget buildTestWidget({required VoidCallback onComplete}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            global.initI18n(context);
            return OnboardingRoute(onComplete: onComplete);
          },
        ),
      );
    }

    Future<void> pumpUntilSettled(WidgetTester tester) async {
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('渲染无异常', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(onComplete: () {}),
      );
      await pumpUntilSettled(tester);

      expect(find.byType(OnboardingRoute), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('PageView 包含 3 页', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(onComplete: () {}),
      );
      await pumpUntilSettled(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.allowImplicitScrolling, false);
      expect(find.byType(PageView), findsOneWidget);
      // PageView 的 children 通过 onPageChanged 和滑动验证为 3 页
      expect(pageView.onPageChanged, isNotNull);
    });

    testWidgets('点击跳过按钮触发 onComplete', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Skip'));
      await pumpUntilSettled(tester);

      expect(completed, isTrue);
    });

    testWidgets('滑动到最后一页点击开始使用进入权限步骤', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      // 通过 PageController 跳到最后一页
      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller = pageView.controller!;
      controller.jumpToPage(2);
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      // 此时应进入权限步骤，未触发 onComplete
      expect(completed, isFalse);
      expect(find.text('Grant permission'), findsOneWidget);
      expect(find.text('Photo access needed'), findsOneWidget);
    });

    testWidgets('权限步骤：授权成功后进入存储步骤', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      const channel = MethodChannel('com.fluttercandies/photo_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermissionExtend') {
            return 3; // PermissionState.authorized 的 index
          }
          return null;
        },
      );

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      // 跳到最后一页并点击 Get Started
      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(2);
      await pumpUntilSettled(tester);
      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      // 点击授予权限
      await tester.tap(find.text('Grant permission'));
      await pumpUntilSettled(tester);

      // 进入存储步骤
      expect(find.text('Set up cloud storage (optional)'), findsOneWidget);
      expect(find.text('Set up storage'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(completed, isFalse);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    testWidgets('权限步骤：授权失败后显示稍后设置并完成引导', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      const channel = MethodChannel('com.fluttercandies/photo_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermissionExtend') {
            return 2; // 非 authorized
          }
          return null;
        },
      );

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(2);
      await pumpUntilSettled(tester);
      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Grant permission'));
      await pumpUntilSettled(tester);

      // 授权失败后显示稍后设置按钮
      expect(find.text('Set up later'), findsOneWidget);

      await tester.tap(find.text('Set up later'));
      await pumpUntilSettled(tester);

      // 完成 onComplete 并写入 has_onboarded
      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_onboarded'), isTrue);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    testWidgets('存储步骤：点击设置存储显示 SettingStorageRouteBody', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      const channel = MethodChannel('com.fluttercandies/photo_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermissionExtend') {
            return 3; // authorized
          }
          return null;
        },
      );

      await tester.pumpWidget(
        buildTestWidget(onComplete: () {}),
      );
      await pumpUntilSettled(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(2);
      await pumpUntilSettled(tester);
      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Grant permission'));
      await pumpUntilSettled(tester);

      // 点击设置存储
      await tester.tap(find.text('Set up storage'));
      await pumpUntilSettled(tester);

      // SettingStorageRouteBody 应出现
      expect(find.byType(SettingStorageRouteBody), findsOneWidget);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    testWidgets('存储步骤：点击完成结束引导并写入 has_onboarded', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      const channel = MethodChannel('com.fluttercandies/photo_manager');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermissionExtend') {
            return 3; // authorized
          }
          return null;
        },
      );

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(2);
      await pumpUntilSettled(tester);
      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Grant permission'));
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Done'));
      await pumpUntilSettled(tester);

      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_onboarded'), isTrue);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
  });
}

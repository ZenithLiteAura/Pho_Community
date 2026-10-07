import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:img_syncer/app/state/community_info.dart';
import 'package:img_syncer/app/widgets/startup_notice_dialog.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

/// 把宿主包进带本地化代理的 MaterialApp，并在首帧后调用
/// [showStartupNoticeIfNeeded]，模拟应用启动时的接线方式。
Future<void> pumpAppAndShow(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(body: SizedBox.expand()),
  ));
  final context = tester.element(find.byType(Scaffold));
  unawaited(showStartupNoticeIfNeeded(context));
  await tester.pump(); // 让 prefs future 与 showDialog 落地
  await tester.pump(const Duration(milliseconds: 400)); // 路由过渡
}

FilledButton closeButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void main() {
  setUp(() {
    resetStartupNoticeShownForTest();
  });

  testWidgets('未关闭开关时弹出弹窗，且 10 秒内关闭按钮禁用', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpAppAndShow(tester);

    expect(find.byType(StartupNoticeDialog), findsOneWidget);
    expect(closeButton(tester).onPressed, isNull,
        reason: '倒计时结束前关闭按钮必须处于禁用状态');

    // 弹窗内展示原作者与仓库链接
    expect(find.text(originalAuthor), findsOneWidget);
    expect(find.text(originalAuthorRepo), findsOneWidget);

    // 弹窗内直接给出「如何关闭它」的指引，用户不用去猜设置在哪一层
    expect(find.textContaining('关闭启动前弹窗'), findsOneWidget);
  });

  testWidgets('10 秒内点击遮罩无法关闭弹窗', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpAppAndShow(tester);

    await tester.tapAt(const Offset(8, 8)); // 弹窗之外的遮罩区域
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(StartupNoticeDialog), findsOneWidget);
  });

  testWidgets('倒计时结束后关闭按钮可用，点击可关闭', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpAppAndShow(tester);

    for (var i = 0; i < startupNoticeLockSeconds; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(closeButton(tester).onPressed, isNotNull,
        reason: '$startupNoticeLockSeconds 秒后必须允许关闭');

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(StartupNoticeDialog), findsNothing);
  });

  testWidgets('开关打开（startup_notice_disabled=true）时不弹窗', (tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{startupNoticePrefKey: true});
    await pumpAppAndShow(tester);

    expect(find.byType(StartupNoticeDialog), findsNothing);
  });

  testWidgets('同一进程内只弹一次', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpAppAndShow(tester);
    expect(find.byType(StartupNoticeDialog), findsOneWidget);

    // 再次调用不应叠加第二个弹窗（进程内已标记为弹过）。
    final context = tester.element(find.byType(StartupNoticeDialog));
    unawaited(showStartupNoticeIfNeeded(context));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(StartupNoticeDialog), findsOneWidget);
  });
}

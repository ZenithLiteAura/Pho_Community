import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/widgets/liquid_glass_toast.dart';

/// 顶部液态玻璃提示条的行为契约。
///
/// 重点锁住两点需求：**位置在顶部**（不再遮挡底部操作区）与**宽度收窄**。
void main() {
  /// 构建一个带 Overlay 的最小宿主（MaterialApp 自带 Navigator Overlay）。
  Widget host({required String message}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => LiquidGlassToast.show(context, message),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
  }

  tearDown(() {
    // 避免计时器悬挂导致 "A Timer is still pending" 报错
    LiquidGlassToast.dismiss();
  });

  testWidgets('提示显示在屏幕顶部，且宽度受限', (WidgetTester tester) async {
    await tester.pumpWidget(host(message: '这是一条测试提示'));
    await tester.tap(find.text('trigger'));
    await tester.pump(); // 插入 OverlayEntry
    await tester.pump(const Duration(milliseconds: 300)); // 播完进入动画

    expect(find.text('这是一条测试提示'), findsOneWidget);

    final textRect = tester.getRect(find.text('这是一条测试提示'));
    // 顶部锚定：紧贴状态栏下方，远离屏幕中部与底部
    expect(textRect.top, lessThan(100));
    expect(textRect.top, greaterThanOrEqualTo(0));

    // 玻璃层宽度受限（不铺满 800 宽的测试屏幕）
    final glassRect = tester.getRect(find.byType(BackdropFilter).first);
    expect(glassRect.width, lessThanOrEqualTo(420));
    expect(glassRect.width, lessThan(800));
    // 且水平居中
    expect((glassRect.center.dx - 400).abs(), lessThan(1));

    // 在测试体内清掉挂起的自动消失计时器：
    // 框架的 "Timer is still pending" 检查早于 tearDown，必须在此处收尾。
    LiquidGlassToast.dismiss();
    await tester.pump();
  });

  testWidgets('到时长后自动消失', (WidgetTester tester) async {
    await tester.pumpWidget(host(message: '会自己消失'));
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('会自己消失'), findsOneWidget);

    // 默认展示 3s，推过之后应被移除
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('会自己消失'), findsNothing);
  });

  testWidgets('连续触发时替换上一条，不堆叠', (WidgetTester tester) async {
    await tester.pumpWidget(host(message: '第一条'));
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('第一条'), findsOneWidget);

    // 换一条内容再次触发
    await tester.pumpWidget(host(message: '第二条'));
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('第二条'), findsOneWidget);
    expect(find.text('第一条'), findsNothing);

    LiquidGlassToast.dismiss();
    await tester.pump();
  });

  testWidgets('空消息不显示任何提示', (WidgetTester tester) async {
    await tester.pumpWidget(host(message: '   '));
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BackdropFilter), findsNothing);
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/widgets/motion/miuix_glass_surface.dart';
import 'package:img_syncer/app/widgets/motion/miuix_overlay.dart';

Widget host({required String buttonText, required void Function(BuildContext) onPressed}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: Text(buttonText),
          ),
        ),
      ),
    ),
  );
}

Widget sampleDialog(String title) => AlertDialog(
      title: Text(title),
      content: const Text('内容'),
      actions: [
        TextButton(onPressed: () {}, child: const Text('OK')),
      ],
    );

void main() {
  testWidgets('showMiuixDialog 默认不再套玻璃盒（对话框自己是唯一的面）', (tester) async {
    await tester.pumpWidget(host(
      buttonText: 'open',
      onPressed: (ctx) => showMiuixDialog<String>(
        context: ctx,
        builder: (_) => sampleDialog('连接失败'),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('连接失败'), findsOneWidget);
    expect(find.byType(MiuixGlassSurface), findsNothing);
    final ctx = tester.element(find.byType(AlertDialog));
    expect(Theme.of(ctx).dialogTheme.backgroundColor, isNot(Colors.transparent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('显式 wrapInGlass: true 时：有玻璃，且里面的 AlertDialog 表面透明', (tester) async {
    await tester.pumpWidget(host(
      buttonText: 'openGlass',
      onPressed: (ctx) => showMiuixDialog<String>(
        context: ctx,
        wrapInGlass: true,
        builder: (_) => sampleDialog('玻璃弹窗'),
      ),
    ));
    await tester.tap(find.text('openGlass'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(MiuixGlassSurface), findsOneWidget);
    final ctx = tester.element(find.byType(AlertDialog));
    final dt = Theme.of(ctx).dialogTheme;
    expect(dt.backgroundColor, Colors.transparent, reason: '避免内外两层框');
    expect(dt.elevation, 0);
    // 关键回归点：不能再把 insetPadding 归零（3.4.9 的排版 bug）
    expect(dt.insetPadding, isNot(EdgeInsets.zero));
  });

  testWidgets('普通 showDialog 的 AlertDialog 不受影响', (tester) async {
    await tester.pumpWidget(host(
      buttonText: 'openPlain',
      onPressed: (ctx) => showDialog<String>(
        context: ctx,
        builder: (_) => sampleDialog('普通弹窗'),
      ),
    ));
    await tester.tap(find.text('openPlain'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final ctx = tester.element(find.byType(AlertDialog));
    expect(Theme.of(ctx).dialogTheme.backgroundColor, isNot(Colors.transparent));
    expect(find.byType(MiuixGlassSurface), findsNothing);
  });
}

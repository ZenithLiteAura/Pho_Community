import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/widgets/motion/miuix_overlay.dart';

Widget host() => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showMiuixDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('连接失败'),
                  content: const Text('详情'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('showMiuixDialog 内的 AlertDialog 不再自带表面（避免两层框）', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('连接失败'), findsOneWidget);

    final ctx = tester.element(find.byType(AlertDialog));
    final dt = Theme.of(ctx).dialogTheme;
    expect(dt.backgroundColor, Colors.transparent, reason: '背景应让给玻璃盒');
    expect(dt.elevation, 0, reason: '不应再有独立阴影层');
    expect(dt.insetPadding, EdgeInsets.zero, reason: '不应再往里缩一圈');
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通 showDialog 的 AlertDialog 保留自己的表面', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('普通弹窗'),
                  content: const Text('内容'),
                ),
              ),
              child: const Text('open2'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final ctx = tester.element(find.byType(AlertDialog));
    // 主题里配的是 cs.surface，这里只断言「不是透明的」
    expect(Theme.of(ctx).dialogTheme.backgroundColor, isNot(Colors.transparent));
  });
}

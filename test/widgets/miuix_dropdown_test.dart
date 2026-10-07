import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/widgets/miuix_dropdown.dart';

Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  final items = const [
    MiuixDropdownItem<int>(value: 0, label: 'SMB', summary: '局域网共享'),
    MiuixDropdownItem<int>(value: 1, label: 'WebDAV', summary: '443 / 80'),
    MiuixDropdownItem<int>(value: 2, label: 'NFS', summary: '2049'),
  ];

  testWidgets('MiuixDropdownTile：点行弹出锚定面板，选中后回传并收起', (tester) async {
    int? picked;
    await tester.pumpWidget(host(MiuixDropdownTile<int>(
      title: '存储协议',
      value: 0,
      items: items,
      onChanged: (v) => picked = v,
    )));

    // 未展开时行内显示当前值
    expect(find.text('存储协议'), findsOneWidget);
    expect(find.text('SMB'), findsOneWidget);

    await tester.tap(find.text('存储协议'));
    await tester.pump();                                   // 启动形变
    await tester.pump(const Duration(milliseconds: 400));    // 形变完成

    // 面板内容出现（含未选中的项）
    expect(find.text('WebDAV'), findsOneWidget);
    expect(find.text('NFS'), findsOneWidget);
    expect(find.text('443 / 80'), findsOneWidget);

    await tester.tap(find.text('WebDAV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));    // 缩回
    expect(picked, 1);
    expect(find.text('WebDAV'), findsNothing);               // 面板已收起
  });

  testWidgets('MiuixDropdownTile：点面板外部关闭，不回传', (tester) async {
    int? picked;
    await tester.pumpWidget(host(MiuixDropdownTile<int>(
      title: '存储协议',
      value: 0,
      items: items,
      onChanged: (v) => picked = v,
    )));

    await tester.tap(find.text('存储协议'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('NFS'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));                // 面板之外
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(picked, isNull);
    expect(find.text('NFS'), findsNothing);
  });

  testWidgets('MiuixDropdownField：表单触发器同样走锚定面板', (tester) async {
    int? picked;
    await tester.pumpWidget(host(SizedBox(
      width: 320,
      child: MiuixDropdownField<int>(
        label: '存储协议',
        value: 0,
        items: items,
        onChanged: (v) => picked = v,
      ),
    )));

    await tester.tap(find.byType(MiuixDropdownField<int>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('NFS'), findsOneWidget);

    await tester.tap(find.text('NFS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(picked, 2);
  });
}

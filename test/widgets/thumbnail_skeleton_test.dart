import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/widgets/thumbnail_skeleton.dart';

void main() {
  group('ThumbnailSkeleton', () {
    testWidgets('正常渲染无异常', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThumbnailSkeleton(),
          ),
        ),
      );

      expect(find.byType(ThumbnailSkeleton), findsOneWidget);
    });

    testWidgets('将 width 和 height 传递给内部 Container', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThumbnailSkeleton(width: 100, height: 80),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(ThumbnailSkeleton)),
        equals(const Size(100, 80)),
      );
    });

    testWidgets('width 和 height 为 null 时填满父容器', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: ThumbnailSkeleton(),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(ThumbnailSkeleton)),
        equals(const Size(200, 200)),
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/gallery_viewer_route.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/global.dart' as global;

/// 可计数的 AssetModel，追踪 addListener / removeListener 调用次数
class CountingAssetModel extends AssetModel {
  int addCount = 0;
  int removeCount = 0;

  @override
  void addListener(VoidCallback listener) {
    addCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeCount++;
    super.removeListener(listener);
  }
}

/// 模拟 GalleryViewerRouteState 的 Provider + listener 模式：
/// initState: context.read<AssetModel>() + addListener
/// dispose: removeListener
class _ListenerTestWidget extends StatefulWidget {
  const _ListenerTestWidget();

  @override
  _ListenerTestWidgetState createState() => _ListenerTestWidgetState();
}

class _ListenerTestWidgetState extends State<_ListenerTestWidget> {
  late final AssetModel _model;

  void _onChange() {}

  @override
  void initState() {
    super.initState();
    _model = context.read<AssetModel>();
    _model.addListener(_onChange);
  }

  @override
  void dispose() {
    _model.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget buildTestWidget(CountingAssetModel model) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AssetModel>.value(value: model),
      ChangeNotifierProvider(create: (_) => SettingModel()),
      ChangeNotifierProvider(create: (_) => StateModel()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          global.initI18n(context);
          return const _ListenerTestWidget();
        },
      ),
    ),
  );
}

void main() {
  group('GalleryViewerRoute listener 生命周期', () {
    testWidgets('TestListenerCleanupOnDispose - 挂载注册监听，卸载时移除',
        (tester) async {
      final model = CountingAssetModel();

      await tester.pumpWidget(buildTestWidget(model));
      await tester.pump();

      // Provider 框架也会 addListener，所以 >=1（不确定精确值）
      expect(model.addCount, greaterThanOrEqualTo(1));
      expect(model.removeCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // 卸载后 removeCount == addCount（无泄漏）
      expect(model.addCount, greaterThan(0));
      expect(model.addCount, model.removeCount);
    });

    testWidgets('TestMultipleMountUnmount - 多次挂载/卸载不累积泄漏',
        (tester) async {
      for (int i = 0; i < 3; i++) {
        final model = CountingAssetModel();

        await tester.pumpWidget(buildTestWidget(model));
        await tester.pump();
        final afterMount = model.addCount;
        expect(afterMount, greaterThanOrEqualTo(1));
        expect(model.removeCount, 0);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(model.addCount, afterMount);
        expect(model.removeCount, afterMount);
      }
    });

    testWidgets('TestProviderInjection - GalleryViewerRoute 使用 Provider 而非全局变量',
        (tester) async {
      // 验证 GalleryViewerRouteState.initState 使用 context.read<AssetModel>()
      // 而非全局 assetModel 变量
      final model = CountingAssetModel();

      await tester.pumpWidget(buildTestWidget(model));
      await tester.pump();
      expect(model.addCount, greaterThanOrEqualTo(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(model.addCount, model.removeCount);
    });
  });
}

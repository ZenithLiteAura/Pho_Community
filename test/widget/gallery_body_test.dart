import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:img_syncer/gallery_body.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/global.dart' as global;
import 'package:img_syncer/l10n/app_localizations.dart';

/// 可计数的 SettingModel，追踪 addListener / removeListener 调用次数
class CountingSettingModel extends SettingModel {
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

void main() {
  group('GalleryBody listener 生命周期', () {
    late CountingSettingModel countingModel;
    late SettingModel originalModel;

    Widget buildTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingModel>.value(value: countingModel),
          ChangeNotifierProvider(create: (_) => AssetModel()),
          ChangeNotifierProvider(create: (_) => StateModel()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              global.initI18n(context);
              return GalleryBody(useLocal: true, showAppBar: false);
            },
          ),
        ),
      );
    }

    setUp(() {
      originalModel = settingModel;
      countingModel = CountingSettingModel();
      // 替换全局 settingModel，使 GalleryBodyState 使用可计数的实例
      settingModel = countingModel;
    });

    tearDown(() {
      settingModel = originalModel;
    });

    testWidgets('挂载时注册 listener，卸载时移除', (tester) async {
      // 初始状态：尚无人调用
      expect(countingModel.addCount, 0);
      expect(countingModel.removeCount, 0);

      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // 挂载后：addListener 应被调用 1 次
      expect(countingModel.addCount, 1);

      // 卸载 GalleryBody：pump 一个不含 GalleryBody 的新 widget
      await tester.pumpWidget(SizedBox.shrink());
      await tester.pump();

      // 卸载后：removeListener 应被调用 1 次
      expect(countingModel.removeCount, 1);
    });

    testWidgets('多次挂载/卸载不累积泄漏', (tester) async {
      for (int i = 0; i < 3; i++) {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        expect(countingModel.addCount, i + 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(countingModel.removeCount, i + 1);
      }

      // 最终 add 和 remove 次数应相等（无累积泄漏）
      expect(countingModel.addCount, 3);
      expect(countingModel.removeCount, 3);
    });
  });
}

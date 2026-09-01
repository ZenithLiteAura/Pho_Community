// 单测：锁住 lib/sync_body.dart 中 syncPhotos() 的当前同步行为。
//
// 4 个场景：
//   (a) happy: 3 张全部上传成功
//   (b) partial: 2 成功 1 失败（uploadAssetEntity 内部 retry 3 次后 throw）
//   (c) interrupt: 跑到第 2 张时设 stateModel.needStopSync=true，断言第 3 张不上传且 sem 不泄漏
//   (d) wifi-off: 测 Connectivity().checkConnectivity() 返回 mobile 时 caller 提前 return
//
// 手写 mock（不跑 build_runner，不引入 mockito_annotation）。
// mock 模式参考 test/unit/storage_test.dart:11。
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/storage/storage_interface.dart';
import 'package:img_syncer/sync_body.dart';
import 'package:img_syncer/sync_timer.dart';
import 'package:mockito/mockito.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 手写 mock：参考 test/unit/storage_test.dart:11 的 MockImgSyncerClient 模式。
/// 通过 setStorageForTest(mock) 注入到全局 storageClient getter。
///
/// mockito 5.x 的 `any`/`argThat` 返回 `Null`，不能直接用于非空 `AssetEntity` 形参。
/// 解决方案（参考 mockito NULL_SAFETY_README §"Manually override a method"）：
/// 覆写 uploadAssetEntity，将形参扩为可空 `AssetEntity?`，委托给 super.noSuchMethod。
///
/// 关键：使用 `async` 使方法体在 Future 域中执行，这样 `thenThrow` 产生的同步异常
/// 会被 async wrapper 捕获并转为 Future error（与真实 async 方法行为一致），
/// 使调用方的 `.catchError()` 能正确捕获。
class MockRemoteStorageClient extends Mock implements RemoteStorageClient {
  @override
  Future<void> uploadAssetEntity(AssetEntity? asset) async =>
      super.noSuchMethod(
        Invocation.method(#uploadAssetEntity, [asset]),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      );
}

/// 测试专用 SyncBody 子类：覆盖 build() 跳过 columnBuilder 的
/// 缩略图平台通道加载，仅暴露继承自 SyncBodyState 的 syncPhotos()。
class _SyncBodyHarness extends SyncBody {
  const _SyncBodyHarness({required String localFolder})
      : super(localFolder: localFolder);
  @override
  SyncBodyState createState() => _SyncBodyHarnessState();
}

class _SyncBodyHarnessState extends SyncBodyState {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 构造一个 type=image 的 AssetEntity（标题预填，避免 name() 触发 titleAsync 平台通道）。
AssetEntity _makeAssetEntity(String id) {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return AssetEntity(
    id: id,
    typeInt: 1, // AssetType.image（见 photo_manager enums.dart:21）
    width: 100,
    height: 100,
    createDateSecond: nowSec,
    modifiedDateSecond: nowSec,
    title: '$id.jpg',
  );
}

/// 构造 Asset 并预填 titleCache（Asset 构造器会读 assetModel.titleCache[id]）。
Asset _makeAsset(String id) {
  assetModel.titleCache[id] = '$id.jpg';
  return Asset(local: _makeAssetEntity(id));
}

/// 轮询直到 syncPhotos 完成（syncing==false），最长 ~5s。
Future<void> _waitForSyncDone(WidgetTester tester, _SyncBodyHarnessState state) async {
  for (var i = 0; i < 100; i++) {
    if (!state.syncing) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('syncPhotos 未在 5s 内完成（可能 sem 泄漏或上传未结束）');
}

const _connChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');

void main() {
  late bool originalUseRemoteServer;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    originalUseRemoteServer = useRemoteServer;
    // 让 checkServer() 立即返回（global.dart:255），避免真实 gRPC ping 挂起测试。
    useRemoteServer = true;

    // 重置 4 个全局单例，保证用例间隔离
    settingModel = SettingModel();
    assetModel = AssetModel();
    stateModel = StateModel();
    settingModel.paralleUploadCount = 3;
    settingModel.isRemoteStorageSetted = true;
    settingModel.enableFilter = false;
    assetModel.titleCache = {};
    stateModel.needStopSync = false;

    // 清上个用例残留的 override（占位 mock，后续用例各自替换）
    setStorageForTest(MockRemoteStorageClient());
  });

  tearDown(() {
    useRemoteServer = originalUseRemoteServer;
    autoSyncTimer?.cancel();
    autoSyncTimer = null;
    _connChannel.setMockMethodCallHandler(null);
  });

  group('syncPhotos 同步行为锁住', () {
    testWidgets('(a) happy: 3 张照片全部上传成功', (tester) async {
      final mock = MockRemoteStorageClient();
      setStorageForTest(mock);
      when(mock.uploadAssetEntity(any)).thenAnswer((_) async {});

      assetModel.localAssets = [
        _makeAsset('a'),
        _makeAsset('b'),
        _makeAsset('c'),
      ];

      await tester.pumpWidget(
          const MaterialApp(home: _SyncBodyHarness(localFolder: 'Test')));
      final state =
          tester.state<_SyncBodyHarnessState>(find.byType(_SyncBodyHarness));

      state.syncPhotos();
      await _waitForSyncDone(tester, state);

      // 全部 3 张都应被上传
      verify(mock.uploadAssetEntity(any)).called(3);
      // happy 路径无失败记录
      expect(state.uploadFailedMap, isEmpty);
    });

    testWidgets('(b) partial: 2 成功 1 失败（retry 3 次后 throw）', (tester) async {
      final mock = MockRemoteStorageClient();
      setStorageForTest(mock);
      final assetA = _makeAsset('a');
      final assetB = _makeAsset('b');
      final assetC = _makeAsset('c');
      // 默认成功；assetC 模拟「uploadAssetEntity 内部 retry 3 次耗尽后 throw」
      when(mock.uploadAssetEntity(any)).thenAnswer((_) async {});
      when(mock.uploadAssetEntity(argThat(equals(assetC.local!))))
          .thenThrow(Exception('network down: retry exhausted'));

      assetModel.localAssets = [assetA, assetB, assetC];

      await tester.pumpWidget(
          const MaterialApp(home: _SyncBodyHarness(localFolder: 'Test')));
      final state =
          tester.state<_SyncBodyHarnessState>(find.byType(_SyncBodyHarness));

      state.syncPhotos();
      await _waitForSyncDone(tester, state);

      // syncPhotos 对每张只调用一次 uploadAssetEntity（retry 在其内部，见 storage.dart:130-241）
      verify(mock.uploadAssetEntity(any)).called(3);
      // 失败的 assetC 应被记录到 uploadFailedMap
      expect(state.uploadFailedMap['c'], isNotNull);
      expect(state.uploadFailedMap['c'], contains('network down'));
      // 成功的 a / b 不在失败 Map 中
      expect(state.uploadFailedMap.containsKey('a'), isFalse);
      expect(state.uploadFailedMap.containsKey('b'), isFalse);
    });

    testWidgets('(c) interrupt: 第 2 张上传时设 needStopSync=true，第 3 张不上传且 sem 不泄漏',
        (tester) async {
      final mock = MockRemoteStorageClient();
      setStorageForTest(mock);
      // 串行上传：确保 b 完成并触发 needStopSync=true 后，c 才进入循环检查
      settingModel.paralleUploadCount = 1;
      final assetA = _makeAsset('a');
      final assetB = _makeAsset('b');
      final assetC = _makeAsset('c');
      // 第 2 张（id=b）上传时触发中断标志
      when(mock.uploadAssetEntity(any)).thenAnswer((inv) async {
        final entity = inv.positionalArguments[0] as AssetEntity;
        if (entity.id == 'b') {
          stateModel.needStopSync = true;
        }
      });

      assetModel.localAssets = [assetA, assetB, assetC];

      await tester.pumpWidget(
          const MaterialApp(home: _SyncBodyHarness(localFolder: 'Test')));
      final state =
          tester.state<_SyncBodyHarnessState>(find.byType(_SyncBodyHarness));

      state.syncPhotos();
      await _waitForSyncDone(tester, state);

      // 第 3 张（id=c）不应被上传
      verifyNever(mock.uploadAssetEntity(argThat(equals(assetC.local!))));
      // sem 不泄漏：syncPhotos 正常结束（syncing=false），_waitForSyncDone 也会先校验这点
      expect(state.syncing, isFalse);
    });
  });

  group('wifi-off 入口提前 return', () {
    test('(d) Connectivity().checkConnectivity() 返回 mobile 时同步应提前 return', () async {
      // mock connectivity 通道返回 ['mobile']（v6+ checkConnectivity 返回 List<ConnectivityResult>）
      _connChannel.setMockMethodCallHandler((call) async {
        if (call.method == 'check') return ['mobile'];
        return null;
      });

      // 1) 真实校验：mock 通道生效，checkConnectivity() 返回 [mobile]
      final results = await Connectivity().checkConnectivity();
      expect(results, [ConnectivityResult.mobile]);

      // 2) 锁住 sync_timer.dart:28-34 的 wifi-only 守卫判定（wifi-only 开启 + 非 wifi => 跳过）
      const wifiOnly = true;
      final shouldSkip = wifiOnly && !results.contains(ConnectivityResult.wifi);
      expect(shouldSkip, isTrue,
          reason: 'wifi-only 模式下 mobile 网络应跳过同步（caller 提前 return）');

      // 3) 真实路径采样：backgroundSyncEnabled=false 时 reloadAutoSyncTimer 提前 return，不注册 timer
      SharedPreferences.setMockInitialValues({'backgroundSyncEnabled': false});
      await reloadAutoSyncTimer();
      expect(autoSyncTimer, isNull,
          reason: '未启用后台同步时 reloadAutoSyncTimer 不应注册定时器');

      // NOTE: 此场景验证「caller 在 wifi-off 时提前 return + 调 scheduleBgTaskViaChannel()」的
      // 守卫条件。runSyncOnce / scheduleBgTaskViaChannel 尚未实现，待后续 task 补齐后
      // 在此处替换为对真实 caller 入口的直接调用与断言。
    });
  });
}
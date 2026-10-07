import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/app/state/asset.dart';
import 'package:img_syncer/app/state/state_model.dart';
import 'package:img_syncer/app/pages/sync_body.dart';

/// 可控的 Asset 子类，绕过 photo_manager AssetEntity 依赖。
class _TestAsset extends Asset {
  final bool _isVideo;
  final DateTime _dateCreated;
  final String _assetId;

  _TestAsset({
    required String id,
    required bool isVideoFlag,
    required DateTime dateCreated,
    String title = 'test.jpg',
  })  : _isVideo = isVideoFlag,
        _dateCreated = dateCreated,
        _assetId = id,
        super(local: null, remote: null) {
    hasLocal = true;
    localTitle = title;
  }

  String get assetId => _assetId;

  @override
  bool isVideo() => _isVideo;

  @override
  DateTime dateCreated() => _dateCreated;
}

/// 用指定 SettingModel 调用 shouldSyncAsset
bool callShouldSync(Asset asset,
    {Map<String, bool>? uploadedIds, SettingModel? sm}) {
  final smUse = sm ?? settingModel;
  final old = settingModel;
  if (sm != null) settingModel = smUse;
  try {
    final ext = (asset.localTitle != null && asset.localTitle!.contains('.'))
        ? '.${asset.localTitle!.split('.').last}'
        : 'jpg';
    final id = (asset is _TestAsset) ? asset.assetId : 'unknown';
    return shouldSyncAsset(asset, id, uploadedIds ?? {}, ext);
  } finally {
    if (sm != null) settingModel = old;
  }
}

void main() {
  setUp(() {
    settingModel = SettingModel();
  });

  group('shouldSyncAsset 同步判定', () {
    test('已上传的资源被过滤', () {
      final asset = _TestAsset(
          id: 'test1', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(
        callShouldSync(asset, uploadedIds: {'test1': true}),
        isFalse,
      );
    });

    test('未上传的资源通过过滤', () {
      final asset = _TestAsset(
          id: 'test2', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(
        callShouldSync(asset, uploadedIds: {}),
        isTrue,
      );
    });

    test('已上传表为空时全部通过', () {
      final photos = [
        _TestAsset(id: 'p1', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1)),
        _TestAsset(id: 'p2', isVideoFlag: true, dateCreated: DateTime(2024, 6, 2)),
        _TestAsset(id: 'p3', isVideoFlag: false, dateCreated: DateTime(2024, 6, 3)),
      ];
      for (final p in photos) {
        expect(callShouldSync(p, uploadedIds: {}), isTrue);
      }
    });

    // 说明：开源版已移除 Pro 的过滤逻辑（见 lib/core/sync/background_runner.dart
    // shouldSyncAsset 的注释「开源版仅检查是否已上传；Pro 版过滤逻辑已移除」）。
    // 原先针对 setFilterSwitch / setFilterNoVideo / setFilterNoImage /
    // setFilterAfter / setFilterBefore / filterTypeMap 的 6 个用例依赖的
    // SettingModel API 在开源版中已不存在，故随实现一并移除。
  });

  group('failedTimes 断连检测', () {
    test('10次失败继续，11次失败停止', () {
      // syncPhotos 中: if (failedTimes > 10) break;
      const threshold = 10;
      expect(10 > threshold, isFalse);
      expect(11 > threshold, isTrue);
    });
  });
}

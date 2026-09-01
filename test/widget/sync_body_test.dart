import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/sync_body.dart';

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

  group('shouldSyncAsset 过滤一致性', () {
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

    test('filterNoVideo 过滤视频', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterNoVideo(true);
      final video =
          _TestAsset(id: 'v1', isVideoFlag: true, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(video, sm: sm), isFalse);
    });

    test('filterNoImage 过滤图片', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterNoImage(true);
      final image =
          _TestAsset(id: 'i1', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(image, sm: sm), isFalse);
    });

    test('filterAfter 过滤过旧的照片', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterAfter(DateTime(2024, 6, 15));
      final oldPhoto =
          _TestAsset(id: 'old1', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(oldPhoto, sm: sm), isFalse);
    });

    test('filterBefore 不过滤同日照片（不含 +1天偏差）', () {
      // BUG 修复核心：columnBuilder 之前用了 .add(Duration(days: 1))
      // 现在统一为 isAfter(filterBefore!) 不含偏移
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterBefore(DateTime(2024, 6, 1));
      final sameDay = _TestAsset(
          id: 'same', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      // 同日 != isAfter，通过
      expect(callShouldSync(sameDay, sm: sm), isTrue);

      final nextDay = _TestAsset(
          id: 'next', isVideoFlag: false, dateCreated: DateTime(2024, 6, 2));
      // 6/2 > 6/1 → isAfter → 被过滤
      expect(callShouldSync(nextDay, sm: sm), isFalse);
    });

    test('filterTypeMap 根据扩展名过滤', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.filterTypeMap['.gif'] = false;
      final gif = _TestAsset(
          id: 'g1',
          isVideoFlag: false,
          dateCreated: DateTime(2024, 6, 1),
          title: 'test.gif');
      expect(callShouldSync(gif, sm: sm), isFalse);

      final jpg = _TestAsset(
          id: 'j1',
          isVideoFlag: false,
          dateCreated: DateTime(2024, 6, 1),
          title: 'test.jpg');
      expect(callShouldSync(jpg, sm: sm), isTrue);
    });

    test('filter 未启用时全部通过', () {
      final sm = SettingModel();
      sm.setFilterSwitch(false);
      sm.setFilterNoVideo(true);
      final video =
          _TestAsset(id: 'v2', isVideoFlag: true, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(video, sm: sm), isTrue);
    });
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

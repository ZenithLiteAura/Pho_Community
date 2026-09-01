import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 创建一个模拟响应流，用于测试 receiveResponses。
Stream<T> _mockResponseStream<T>(List<T> items) async* {
  for (final item in items) {
    yield item;
  }
}

void main() {
  group('receiveResponses 两阶段提交', () {
    late StateModel state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = StateModel();
    });

    test('accumulatedIDs 模式仅积累不写入 syncedIDs', () async {
      // 预置一些旧的 syncedIDs
      state.setSyncedPhotos(['old_id_1', 'old_id_2']);
      final preAccumulate = List<String>.from(state.syncedIDs);

      final accumulatedIDs = <String>[];
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['new_id_1', 'new_id_2'],
        ),
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['new_id_3'],
        ),
      ]);

      await receiveResponses(stream, accumulatedIDs: accumulatedIDs);

      // syncedIDs 应保持旧值未被修改
      expect(state.syncedIDs, preAccumulate);
      // accumulatedIDs 应包含所有新 ID
      expect(accumulatedIDs, containsAll(['new_id_1', 'new_id_2', 'new_id_3']));
      expect(accumulatedIDs.length, 3);
    });

    test('accumulatedIDs 模式重复 ID 正常追加（去重在 setSyncedPhotos 调用方执行）',
        () async {
      state.setSyncedPhotos(['old_1']);
      final accumulatedIDs = <String>[];
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['dup_id', 'dup_id', 'unique_id'],
        ),
      ]);

      await receiveResponses(stream, accumulatedIDs: accumulatedIDs);

      // 积累阶段不去重，由调用方处理
      expect(accumulatedIDs.length, 3);
    });

    test('accumulatedIDs 模式遇到错误时不中断，继续处理后续响应', () async {
      state.setSyncedPhotos(['old']);
      final accumulatedIDs = <String>[];
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: false,
          message: 'simulated error',
        ),
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['ok_id'],
        ),
      ]);

      await receiveResponses(stream, accumulatedIDs: accumulatedIDs);

      expect(state.syncedIDs, ['old']);
      expect(accumulatedIDs, ['ok_id']);
    });
  });

  group('receiveResponses 去重模式', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // 直接操作顶层单例 stateModel（receiveResponses 内部引用的是它）
      stateModel.setSyncedPhotos([]);
    });

    test('无 accumulatedIDs 时直接写入并自动去重', () async {
      stateModel.setSyncedPhotos(['existing_1']);
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['existing_1', 'existing_1', 'new_2'],
        ),
      ]);

      await receiveResponses(stream);

      // 应通过 Set 去重
      final ids = stateModel.syncedIDs;
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['existing_1', 'new_2']));
    });

    test('多次响应累计写入并去重', () async {
      stateModel.setSyncedPhotos([]);
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['id_a', 'id_b'],
        ),
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['id_b', 'id_c'],
        ),
      ]);

      await receiveResponses(stream);

      final ids = stateModel.syncedIDs;
      expect(ids.toSet().length, 3);
      expect(ids, containsAll(['id_a', 'id_b', 'id_c']));
    });
  });

  group('syncedIDs 去重逻辑', () {
    late StateModel state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = StateModel();
    });

    test('setSyncedPhotos 后通过 toSet 去重', () {
      final idsWithDup = ['a', 'b', 'a', 'c', 'b'];
      state.setSyncedPhotos(idsWithDup.toSet().toList());
      expect(state.syncedIDs.length, 3);
      expect(state.syncedIDs.toSet().length, 3);
    });
  });
}

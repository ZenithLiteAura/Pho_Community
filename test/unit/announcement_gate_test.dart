import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/announcement_dev_tools.dart';

Announcement buildAnnouncement({
  String id = 'a-1',
  String? startAt,
  String? endAt,
  String? minVersion,
  String? maxVersion,
  bool once = true,
}) {
  return Announcement(
    id: id,
    level: AnnouncementLevel.info,
    title: const LocalizedText(zh: '标题', en: 'Title'),
    body: const LocalizedText(zh: '正文', en: 'Body'),
    startAt: startAt == null ? null : DateTime.parse(startAt),
    endAt: endAt == null ? null : DateTime.parse(endAt),
    minVersion: minVersion,
    maxVersion: maxVersion,
    once: once,
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);
  const appVersion = '3.4.4';

  group('AnnouncementGate.evaluate', () {
    test('所有源都不可用 → allSourcesFailed', () {
      final r = AnnouncementGate.evaluate(
        announcement: null,
        anySourceUsable: false,
        now: now,
        appVersion: appVersion,
        seenIds: const {},
      );
      expect(r.willShow, isFalse);
      expect(r.reason, AnnouncementGateReason.allSourcesFailed);
    });

    test('源可用但 enabled 不是 true → notEnabled', () {
      final r = AnnouncementGate.evaluate(
        announcement: null,
        anySourceUsable: true,
        now: now,
        appVersion: appVersion,
        seenIds: const {},
      );
      expect(r.willShow, isFalse);
      expect(r.reason, AnnouncementGateReason.notEnabled);
    });

    test('不在生效时间窗口内 → outsideWindow', () {
      final future = AnnouncementGate.evaluate(
        announcement: buildAnnouncement(startAt: '2026-11-01T00:00:00Z'),
        anySourceUsable: true,
        now: now,
        appVersion: appVersion,
        seenIds: const {},
      );
      expect(future.reason, AnnouncementGateReason.outsideWindow);

      final expired = AnnouncementGate.evaluate(
        announcement: buildAnnouncement(endAt: '2026-10-01T00:00:00Z'),
        anySourceUsable: true,
        now: now,
        appVersion: appVersion,
        seenIds: const {},
      );
      expect(expired.reason, AnnouncementGateReason.outsideWindow);
    });

    test('版本区间不匹配 → versionMismatch', () {
      final r = AnnouncementGate.evaluate(
        announcement: buildAnnouncement(minVersion: '9.0'),
        anySourceUsable: true,
        now: now,
        appVersion: appVersion,
        seenIds: const {},
      );
      expect(r.willShow, isFalse);
      expect(r.reason, AnnouncementGateReason.versionMismatch);
    });

    test('同一 id 已读过 → alreadySeen', () {
      final r = AnnouncementGate.evaluate(
        announcement: buildAnnouncement(id: 'seen-1'),
        anySourceUsable: true,
        now: now,
        appVersion: appVersion,
        seenIds: const {'seen-1'},
      );
      expect(r.willShow, isFalse);
      expect(r.reason, AnnouncementGateReason.alreadySeen);
    });

    test('once=false 时即使读过也会弹', () {
      final r = AnnouncementGate.evaluate(
        announcement: buildAnnouncement(id: 'seen-1', once: false),
        anySourceUsable: true,
        now: now,
        appVersion: appVersion,
        seenIds: const {'seen-1'},
      );
      expect(r.willShow, isTrue);
      expect(r.reason, AnnouncementGateReason.willShow);
      expect(r.announcement?.id, 'seen-1');
    });

    test('全部条件满足 → willShow', () {
      final r = AnnouncementGate.evaluate(
        announcement: buildAnnouncement(
          startAt: '2026-10-01T00:00:00Z',
          endAt: '2026-11-01T00:00:00Z',
          minVersion: '3.4',
          maxVersion: '4.0',
        ),
        anySourceUsable: true,
        now: now,
        appVersion: appVersion,
        seenIds: const {},
      );
      expect(r.willShow, isTrue);
      expect(r.reason, AnnouncementGateReason.willShow);
    });
  });

  group('公告 JSON 构造（管理工具用）', () {
    test('buildAnnouncementJson 能被 Announcement.parse 解析回来', () {
      final json = buildAnnouncementJson(
        id: 'notice-1',
        level: 'critical',
        titleZh: '中文标题',
        titleEn: 'English title',
        bodyZh: '中文正文',
        bodyEn: 'English body',
        url: 'https://example.com/x',
      );
      final a = Announcement.parse(json);
      expect(a, isNotNull);
      expect(a!.id, 'notice-1');
      expect(a.level, AnnouncementLevel.critical);
      expect(a.dismissible, isFalse);
      expect(a.title.zh, '中文标题');
      expect(a.title.en, 'English title');
      expect(a.url, 'https://example.com/x');
      expect(a.once, isTrue);
    });

    test('buildDisabledAnnouncementJson 解析结果为 null（等于没有公告）', () {
      final json = buildDisabledAnnouncementJson(id: 'x');
      expect(Announcement.parse(json), isNull);
    });
  });
}

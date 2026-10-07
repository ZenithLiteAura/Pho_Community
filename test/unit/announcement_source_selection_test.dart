import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/state/announcement_dev_tools.dart';

Announcement announcement({String id = 'a', String? updatedAt}) => Announcement(
      id: id,
      level: AnnouncementLevel.info,
      title: const LocalizedText(zh: 't', en: 't'),
      body: const LocalizedText(zh: 'b', en: 'b'),
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt),
    );

AnnouncementFetch ok([Announcement? a, DateTime? at]) =>
    AnnouncementFetch(ok: true, announcement: a, updatedAt: at);
const AnnouncementFetch bad = AnnouncementFetch(ok: false);

void main() {
  group('selectNewestAnnouncement', () {
    test('全部源不可用 → anySourceUsable=false', () {
      final r = selectNewestAnnouncement([bad, bad]);
      expect(r.anySourceUsable, isFalse);
      expect(r.announcement, isNull);
    });

    test('都没有 updatedAt 时按优先级取第一条可用源', () {
      final r = selectNewestAnnouncement([
        bad,
        ok(announcement(id: 'priority-2')),
        ok(announcement(id: 'priority-3')),
      ]);
      expect(r.announcement?.id, 'priority-2');
    });

    test('带更新的 updatedAt 的源胜出（即使优先级更低）', () {
      final r = selectNewestAnnouncement([
        ok(announcement(id: 'old', updatedAt: '2026-10-01T00:00:00Z'),
            DateTime.parse('2026-10-01T00:00:00Z')),
        bad,
        ok(announcement(id: 'new', updatedAt: '2026-10-07T00:00:00Z'),
            DateTime.parse('2026-10-07T00:00:00Z')),
      ]);
      expect(r.announcement?.id, 'new');
    });

    test('带 updatedAt 的源压过没有 updatedAt 的旧源', () {
      final r = selectNewestAnnouncement([
        ok(announcement(id: 'no-timestamp'), null),
        ok(announcement(id: 'with-timestamp', updatedAt: '2026-10-07T00:00:00Z'),
            DateTime.parse('2026-10-07T00:00:00Z')),
      ]);
      expect(r.announcement?.id, 'with-timestamp');
    });

    test('最新的一份是 enabled=false → 结果为 null，不回退到更旧的源', () {
      final r = selectNewestAnnouncement([
        ok(announcement(id: 'stale-live'), null),
        ok(null, DateTime.parse('2026-10-07T00:00:00Z')), // 最新：已下线
      ]);
      expect(r.anySourceUsable, isTrue);
      expect(r.announcement, isNull);
    });
  });

  group('updatedAt', () {
    test('从 JSON 解析 updatedAt', () {
      final json = buildAnnouncementJson(
        id: 'u-1',
        level: 'info',
        titleZh: 't',
        titleEn: 't',
        bodyZh: 'b',
        bodyEn: 'b',
      );
      final a = Announcement.parse(json);
      expect(a, isNotNull);
      expect(a!.updatedAt, isNotNull);
      expect(
        DateTime.now().toUtc().difference(a.updatedAt!.toUtc()).inMinutes.abs(),
        lessThanOrEqualTo(2),
      );
    });

    test('下线 JSON 也带 updatedAt（供客户端判定「最新的一份已下线」）', () {
      final json = buildDisabledAnnouncementJson(id: 'x');
      expect(json.contains('updatedAt'), isTrue);
      expect(Announcement.parse(json), isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/state/announcement.dart';

String jsonOf(Map<String, Object?> patch) {
  final base = <String, Object?>{
    'enabled': true,
    'id': 'a-1',
    'level': 'info',
    'title': {'zh': '标题', 'en': 'Title'},
    'body': {'zh': '正文', 'en': 'Body'},
  };
  base.addAll(patch);
  final entries = base.entries
      .where((e) => e.value != null)
      .map((e) => '"' + e.key + '": ' + _encode(e.value))
      .join(', ');
  return '{$entries}';
}

String _encode(Object? v) {
  if (v is String) return '"' + v.replaceAll(r'\', r'\\').replaceAll('"', r'\"') + '"';
  if (v is bool || v is num) return v.toString();
  if (v is Map) {
    final inner = v.entries
        .map((e) => '"' + e.key.toString() + '": ' + _encode(e.value))
        .join(', ');
    return '{$inner}';
  }
  if (v is List) return '[' + v.map(_encode).join(', ') + ']';
  return 'null';
}

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);

  group('Announcement.parse', () {
    test('enabled 非 true 时视为无公告', () {
      expect(Announcement.parse(jsonOf({'enabled': false})), isNull);
      expect(Announcement.parse(jsonOf({'enabled': null})), isNull);
    });

    test('id 为空 / JSON 非法 / 无内容时返回 null', () {
      expect(Announcement.parse(jsonOf({'id': '  '})), isNull);
      expect(Announcement.parse('not json'), isNull);
      expect(Announcement.parse('[]'), isNull);
      expect(
        Announcement.parse(jsonOf({
          'title': {'zh': '', 'en': ''},
          'body': {'zh': '', 'en': ''},
        })),
        isNull,
      );
    });

    test('正常解析：级别、双语、once 默认值', () {
      final a = Announcement.parse(jsonOf({'level': 'critical'}))!;
      expect(a.id, 'a-1');
      expect(a.level, AnnouncementLevel.critical);
      expect(a.once, isTrue);
      expect(a.dismissible, isFalse);
      expect(a.title.resolve(const Locale('zh')), '标题');
      expect(a.title.resolve(const Locale('en')), 'Title');
    });

    test('双语缺失时互相兜底；标题写成单字符串时中英共用', () {
      final a = Announcement.parse(jsonOf({
        'title': '纯字符串标题',
        'body': {'zh': '只有中文'},
      }))!;
      expect(a.title.resolve(const Locale('en')), '纯字符串标题');
      expect(a.body.resolve(const Locale('en')), '只有中文');
    });

    test('level 解析容错', () {
      expect(AnnouncementLevel.parse('warn'), AnnouncementLevel.warning);
      expect(AnnouncementLevel.parse('URGENT'), AnnouncementLevel.critical);
      expect(AnnouncementLevel.parse('whatever'), AnnouncementLevel.info);
      expect(AnnouncementLevel.parse(null), AnnouncementLevel.info);
    });
  });

  group('Announcement.matches', () {
    test('时间窗口', () {
      final open = Announcement.parse(jsonOf({}))!;
      expect(open.matches(now: now, appVersion: '3.4'), isTrue);

      final future = Announcement.parse(jsonOf({
        'startAt': '2026-11-01T00:00:00+08:00',
      }))!;
      expect(future.matches(now: now, appVersion: '3.4'), isFalse);

      final expired = Announcement.parse(jsonOf({
        'endAt': '2026-10-01T00:00:00+08:00',
      }))!;
      expect(expired.matches(now: now, appVersion: '3.4'), isFalse);

      final inWindow = Announcement.parse(jsonOf({
        'startAt': '2026-10-01T00:00:00+08:00',
        'endAt': '2026-11-01T00:00:00+08:00',
      }))!;
      expect(inWindow.matches(now: now, appVersion: '3.4'), isTrue);
    });

    test('版本区间', () {
      final onlyNew = Announcement.parse(jsonOf({'minVersion': '3.5'}))!;
      expect(onlyNew.matches(now: now, appVersion: '3.4'), isFalse);
      expect(onlyNew.matches(now: now, appVersion: '3.5'), isTrue);

      final onlyOld = Announcement.parse(jsonOf({'maxVersion': '3.3'}))!;
      expect(onlyOld.matches(now: now, appVersion: '3.4'), isFalse);
      expect(onlyOld.matches(now: now, appVersion: '3.2'), isTrue);

      final ranged = Announcement.parse(jsonOf({
        'minVersion': '3.0',
        'maxVersion': '3.9',
      }))!;
      expect(ranged.matches(now: now, appVersion: '3.4'), isTrue);
    });

    test('版本号写了 but 解析不出时不限制', () {
      final a = Announcement.parse(jsonOf({'minVersion': 'latest'}))!;
      expect(a.matches(now: now, appVersion: '3.4'), isTrue);
    });
  });

  group('公告源配置', () {
    test('五源齐备且顺序为 raw -> gcore -> github.com -> jsDelivr -> Pages', () {
      expect(announcementSources.length, 5);
      expect(announcementSources[0], contains('raw.githubusercontent.com'));
      expect(announcementSources[1], contains('gcore.jsdelivr.net'));
      expect(announcementSources[2], contains('github.com/'));
      expect(announcementSources[3], contains('cdn.jsdelivr.net'));
      expect(announcementSources[4], contains('github.io'));
      // 带长缓存、容易拿到旧内容的 cdn.jsdelivr 必须排在 gcore 之后
      expect(
        announcementSources.indexOf('https://cdn.jsdelivr.net/gh/'
            'ZenithLiteAura/Pho_Community@main/docs/announcement.json'),
        greaterThan(announcementSources.indexOf(
            'https://gcore.jsdelivr.net/gh/'
            'ZenithLiteAura/Pho_Community@main/docs/announcement.json')),
      );
      // 前四条指向仓库里的 docs/ 目录；Pages 选 /docs 作为站点根目录，URL 里没有这一层。
      for (var i = 0; i < 4; i++) {
        expect(announcementSources[i], endsWith('/docs/announcement.json'));
      }
      expect(announcementSources[4], endsWith('/announcement.json'));
    });
  });
}

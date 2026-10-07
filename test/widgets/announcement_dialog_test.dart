import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:img_syncer/app/state/announcement.dart';
import 'package:img_syncer/app/widgets/announcement_dialog.dart';
import 'package:img_syncer/l10n/app_localizations.dart';

Announcement buildAnnouncement({
  AnnouncementLevel level = AnnouncementLevel.info,
  String? url,
}) {
  return Announcement(
    id: 'test-1',
    level: level,
    title: const LocalizedText(zh: '维护通知', en: 'Maintenance'),
    body: const LocalizedText(zh: '今晚 23:00 起维护', en: 'Maintenance at 23:00'),
    url: url,
  );
}

Future<void> pumpWithDialog(WidgetTester tester, Announcement a) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showAnnouncementDialog(context, a),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('info 公告：点遮罩可以关闭', (tester) async {
    await pumpWithDialog(tester, buildAnnouncement());

    expect(find.byType(AnnouncementDialog), findsOneWidget);
    expect(find.text('维护通知'), findsOneWidget);
    expect(find.text('今晚 23:00 起维护'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementDialog), findsNothing);
  });

  testWidgets('critical 公告：点遮罩关不掉，必须点「我知道了」', (tester) async {
    await pumpWithDialog(
        tester, buildAnnouncement(level: AnnouncementLevel.critical));

    expect(find.text('重要'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementDialog), findsOneWidget,
        reason: 'critical 公告必须点遮罩无法关闭');

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementDialog), findsNothing);
  });

  testWidgets('critical 为默认关闭按钮，info 亦保留「我知道了」', (tester) async {
    await pumpWithDialog(tester, buildAnnouncement());
    expect(find.text('我知道了'), findsOneWidget);
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(find.byType(AnnouncementDialog), findsNothing);
  });

  testWidgets('带 url 时显示「前往查看」与链接文本', (tester) async {
    await pumpWithDialog(
        tester, buildAnnouncement(url: 'https://example.com/notice'));

    expect(find.text('前往查看'), findsOneWidget);
    expect(find.text('https://example.com/notice'), findsOneWidget);
  });
}

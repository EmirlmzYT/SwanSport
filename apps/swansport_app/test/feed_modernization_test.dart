import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/social/presentation/widgets/feed_entry.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('feed starts with content, not administrative or fake story blocks', () {
    final source = File('lib/features/social/presentation/feed_screen.dart').readAsStringSync();
    for (final removed in ['StitchStoriesBar', 'TodayTasks', 'AttendanceQueueBanner']) {
      expect(source.contains(removed), isFalse);
    }
    expect(source.contains('Tümü (Keşfet)'), isTrue);
    expect(source.contains('Takip Ettiklerim'), isTrue);
    expect(source.contains('newsProvider'), isTrue);
  });
  test('wordmark and inbox use shared tokens and real counts', () {
    final header = File('lib/features/social/presentation/widgets/stitch_feed_widgets.dart').readAsStringSync();
    expect(header.contains('GoogleFonts'), isFalse);
    expect(header.contains('Color(0x'), isFalse);
    expect(header.contains('unreadNotificationsProvider'), isTrue);
    expect(header.contains('unreadMessagesProvider'), isTrue);
    expect(header.contains('SwanType.wordmark(c.ink)'), isTrue);
    final type = File('lib/app/design/swan_type.dart').readAsStringSync();
    expect(type.contains('grandHotel'), isFalse);
  });
  test('post actions and animation survive borderless shell', () {
    final source = File('lib/features/social/presentation/widgets/post_card.dart').readAsStringSync();
    for (final action in ['_likePop.dispose()', '_toggleLike', '_openComments', '_openMenu', '_toggleSaved', 'showShareSheet', 'showRepostSheet']) {
      expect(source.contains(action), isTrue);
    }
    expect(source.contains('Border.all'), isFalse);
    expect(source.contains('BoxShadow'), isFalse);
    expect(source.contains('Color(0x'), isFalse);
  });
  for (final scheme in ['https://example.com/news', 'javascript:alert(1)', '']) {
    testWidgets('news editorial label and safe link: $scheme', (tester) async {
      final item = NewsItem(title: 'Günün spor haberi', sourceName: 'Spor Kaynağı', publishedAt: DateTime(2026, 10, 12), summary: 'Haber özeti', link: scheme);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: [NewsCard(item: item)]))));
      expect(find.text('SPOR GÜNDEMİ'), findsOneWidget);
      expect(find.text('Günün spor haberi'), findsOneWidget);
      expect(find.text('Haber özeti'), findsOneWidget);
      expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 16 / 9);
      expect(find.text('Haberi Oku ↗'), scheme.startsWith('https') ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

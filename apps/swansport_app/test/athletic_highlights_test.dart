import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/features/social/presentation/widgets/athletic_highlights.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('archery and running explicit summaries become stat strips', () {
    expect(athleticHighlights('72 Ok · 680 Puan').single.label, '72 Ok · 680 Puan');
    expect(athleticHighlights('5.2 km Koşu · 24 dk').single.label, '5.2 km · 24 dk');
    expect(athleticHighlights('Seans: 5,2 km · 24 dk').single.kind, AthleticHighlightKind.training);
  });
  test('score retains outcome as written, never infers a win', () {
    expect(athleticHighlights('3 - 1 Galibiyet').single.label, '3 - 1 Galibiyet');
    expect(athleticHighlights('Maç skoru: 1 - 3').single.label, 'Maç skoru: 1 - 3');
    expect(athleticHighlights('3 - 1'), isEmpty);
  });
  test('record is an author claim only', () {
    expect(athleticHighlights('Yeni kişisel rekor: 5.2 km').single.kind, AthleticHighlightKind.record);
    expect(athleticHighlights('PR: 24 dk').single.kind, AthleticHighlightKind.record);
  });
  test('dates, times and ordinary text are not match scores', () {
    for (final text in ['Maç 18:30', 'Maç 12-10-2026', 'Spor güzeldir', 'Toplam 5 kişi']) {
      expect(athleticHighlights(text), isEmpty, reason: text);
    }
  });
  test('plans, negations, quotations and questions do not become achievements', () {
    for (final text in ['Hedef 72 Ok · 680 Puan', 'Yeni kişisel rekor değil', '3 - 1 galibiyet olmadı', 'PR: 24 dk?', '“3 - 1 Galibiyet”']) {
      expect(athleticHighlights(text), isEmpty, reason: text);
    }
  });
  test('repeated highlights are bounded by kind', () {
    expect(athleticHighlights('72 Ok · 680 Puan\n72 Ok · 680 Puan').length, 1);
  });
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('highlight wraps on narrow screen: $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: brightness), home: const Scaffold(
        body: AthleticHighlights(body: '72 Ok · 680 Puan\n3 - 1 Galibiyet\nYeni kişisel rekor: 24 dk'),
      )));
      expect(find.text('Paylaşım özeti · Kullanıcı beyanı'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

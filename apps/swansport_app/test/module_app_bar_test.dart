import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('all 20 opted-in screens use the standard Scaffold AppBar', () {
    const titles = {
      'venues': 'Sahalar & Kortlar', 'marketplace': 'Pazaryeri',
      'discover': 'Kulüpler & Akademiler', 'coach_discovery': 'Antrenör Bul',
      'organizations': 'Turnuva & Organizasyonlar', 'finance': 'Kulüp Finansı',
      'team_roster_directory': 'Takımlar & Kadrolar', 'athlete_workspace': 'Sporcular',
      'attendance_history': 'Yoklama Geçmişi', 'document_vault': 'Belge Kasası',
      'announcements': 'Kulüp Duyuruları', 'club_settings': 'Kulüp Ayarları',
      'my_fees': 'Aidatlarım', 'my_training': 'Antrenmanlarım',
      'nutrition_tracker': 'Beslenme Günlüğü', 'readiness_rpe': 'Hazırbulunuşluk & RPE',
      'help': 'Yardım & SSS', 'support': 'Destek Talepleri',
      'notifications': 'Bildirimler', 'saved_posts': 'Kaydedilen Gönderiler',
    };
    final files = Directory('lib/features').listSync(recursive: true).whereType<File>().toList();
    for (final entry in titles.entries) {
      final file = files.singleWhere((f) => f.path.replaceAll('\\', '/').endsWith('/${entry.key}_screen.dart'));
      final source = file.readAsStringSync();
      expect(source.contains("appBar: swanModuleAppBar(context, title: '${entry.value}'"), isTrue, reason: file.path);
      expect(source.contains('SwanPageHeader('), isFalse, reason: file.path);
    }
  });
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('root/pushed route back contract and actions: $brightness', (tester) async {
      var actions = 0;
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: brightness),
        home: Builder(builder: (context) => Scaffold(
          appBar: swanModuleAppBar(context, title: 'Modül', actions: [
            IconButton(tooltip: 'Test aksiyonu', icon: const Icon(Icons.search), onPressed: () => actions++),
          ]),
          body: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (context) => Scaffold(appBar: swanModuleAppBar(context, title: 'Alt Sayfa')))),
            child: const Text('Alt sayfayı aç')),
        ))));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Geri dön'), findsNothing);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.elevation, 0); expect(appBar.scrolledUnderElevation, 0);
      expect(appBar.centerTitle, isFalse);
      await tester.tap(find.byTooltip('Test aksiyonu')); expect(actions, 1);
      await tester.tap(find.text('Alt sayfayı aç')); await tester.pumpAndSettle();
      expect(find.byTooltip('Geri dön'), findsOneWidget);
      await tester.tap(find.byTooltip('Geri dön')); await tester.pumpAndSettle();
      expect(find.text('Modül'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

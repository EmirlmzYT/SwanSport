import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:swansport_app/app/widgets/swan_surface.dart';
import 'package:swansport_app/features/settings/presentation/screens/club_training_sports_sheet.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('standard module title supports subtitle and only nested pages show back', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      appBar: swanModuleAppBar(context, title: 'Root'),
      body: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
        builder: (context) => Scaffold(appBar: swanModuleAppBar(context, title: 'Kort', subtitle: '08:00–22:00')))),
        child: const Text('Open'))))));
    expect(find.byTooltip('Geri dön'), findsNothing);
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    expect(find.text('08:00–22:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri dön')); await tester.pumpAndSettle();
    expect(find.text('Root'), findsOneWidget);
  });
  testWidgets('action card wraps long Turkish labels at narrow width and remains clickable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SizedBox(
      width: 280, child: MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: SwanActionCard(title: 'Lisans ve kimlik doğrulama', icon: Icons.badge_outlined,
          subtitle: 'Hesap ve kulüp işlemlerini buradan yönetebilirsin.', onTap: () => tapped = true)))))));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lisans ve kimlik doğrulama'));
    expect(tapped, isTrue);
  });
  testWidgets('club branch sheet preserves selected sports on failure, supports retry and saves scope', (tester) async {
    var fail = true;
    final saved = <String>[];
    final service = ClubTrainingSportsService((club, codes) async {
      expect(club, 'club');
      if (fail) throw StateError('offline');
      saved.addAll(codes); return codes.length;
    }, () {});
    await tester.pumpWidget(ProviderScope(overrides: [
      activeClubProvider.overrideWith((ref) async => const ClubRef(id: 'club', name: 'Fixture')),
      activeClubSportsProvider.overrideWith((ref) async => catalogSportsFor(['yuzme'])),
      clubTrainingSportsServiceProvider.overrideWithValue(service),
    ], child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true,
        builder: (_) => const FractionallySizedBox(heightFactor: .9,
          child: ClubTrainingSportsSheet(clubId: 'club'))), child: const Text('Branşları aç')))))));
    await tester.tap(find.text('Branşları aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Futbol'); await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Futbol')); await tester.pump();
    await tester.tap(find.text('Kaydet')); await tester.pumpAndSettle();
    expect(find.textContaining('Kaydedilemedi:'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);
    fail = false;
    await tester.tap(find.text('Kaydet')); await tester.pumpAndSettle();
    expect(saved.toSet(), {'yuzme', 'futbol'});
  });
}

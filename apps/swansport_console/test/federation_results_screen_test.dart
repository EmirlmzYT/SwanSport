import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/modules/module_registry.dart';
import 'package:swansport_console/features/federation/federation_results_screen.dart';
import 'package:swansport_data/swansport_data.dart';

class ResultServiceFake extends Fake implements FederationRecordsService {
  int calls = 0;
  Map<String, dynamic>? sent;
  bool fail = false;
  @override
  Future<String> publishOfficialResult(
      {required FederationPendingMatch match,
      required Map<String, dynamic> protocol,
      required String reason}) async {
    calls++;
    sent = protocol;
    if (fail) throw StateError('connection lost');
    return 'revision';
  }
}

SwanAccess officer() => SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 0,
        athleteKind: null,
        federationAppointments: [
          FederationAppointment(
              id: 'duty',
              sportCode: 'tenis',
              cityCode: '34',
              duty: FederationDuty.resultPublisher,
              startsOn: DateTime(2020),
              endsOn: DateTime(2099))
        ]);
const match = FederationPendingMatch(
    id: 'm',
    name: 'Resmi Lig',
    sportCode: 'tenis',
    cityCode: '34',
    version: 0,
    homeName: 'Kulüp A',
    awayName: 'Kulüp B');
void main() {
  test('federation module requires active duty, admin has no bypass', () {
    final module = moduleForRoute('/federasyon-sonuclari')!;
    expect(module.visibleTo(officer()), true);
    expect(module.visibleTo(SwanAccess.none), false);
    expect(
        module.visibleTo(const SwanAccess(
            isPlatformAdmin: true,
            clubRole: 'club_admin',
            coachLevel: 5,
            athleteKind: null)),
        false);
  });
  testWidgets('unauthorized direct screen never loads result queue', (t) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          consoleAccessProvider.overrideWithValue(SwanAccess.none),
          federationPendingResultsProvider(0)
              .overrideWith((_) async => throw StateError('must not call'))
        ],
        child: const MaterialApp(
            home: Scaffold(body: FederationResultsScreen()))));
    await t.pumpAndSettle();
    expect(find.text('Sonuç yayımlama görevi gerekli.'), findsOneWidget);
    expect(find.text('Sonuç Gir'), findsNothing);
  });
  for (final failure in [false, true]) {
    testWidgets(
        failure
            ? 'uncertain publication is checked without repeating'
            : 'typed tennis form validates before RPC', (t) async {
      t.view.physicalSize = const Size(1200, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final service = ResultServiceFake()..fail = failure;
      var serverVersion = 0;
      await t.pumpWidget(ProviderScope(
          overrides: [
            consoleAccessProvider.overrideWithValue(officer()),
            federationRecordsServiceProvider.overrideWithValue(service),
            federationResultCardProvider('m').overrideWith((_) async =>
                FederationResultCard(
                    matchId: 'm',
                    sportCode: 'tenis',
                    version: serverVersion,
                    protocol: null,
                    athletes: const [])),
          ],
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => const Dialog.fullscreen(
                                  child: FederationResultForm(match: match))),
                          child: const Text('Aç')))))));
      await t.tap(find.text('Aç'));
      await t.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label);
      await t.enterText(field('Ev sahibi').at(0), '6');
      await t.enterText(field('Deplasman').at(0), '2');
      await t.enterText(field('Ev sahibi').at(1), '6');
      final publish = find.text('Sonucu Onayla ve Yayınla');
      await t.ensureVisible(publish);
      await t.tap(publish);
      await t.pumpAndSettle();
      expect(service.calls, 0);
      await t.enterText(field('Deplasman').at(1), '0');
      await t.enterText(
          field('Onay / yayın gerekçesi'), 'Hakem sonucu onaylandı');
      await t.ensureVisible(publish);
      await t.tap(publish);
      await t.pumpAndSettle();
      expect(service.calls, 1);
      expect(service.sent!['sets'], [
        {'home': 6, 'away': 2, 'tie_break_target': 7},
        {'home': 6, 'away': 0, 'tie_break_target': 7}
      ]);
      if (failure) {
        expect(find.textContaining('Yayın doğrulanamadı'), findsOneWidget);
        serverVersion = 1;
        await t.tap(find.text('Sunucu durumunu kontrol et'));
        await t.pumpAndSettle();
        expect(service.calls, 1);
      }
      expect(find.text('Aç'), findsOneWidget);
      expect(find.text('Sonucu Onayla ve Yayınla'), findsNothing);
    });
  }
}

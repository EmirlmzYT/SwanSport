import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/teams/presentation/widgets/official_team_rosters.dart';
import 'package:swansport_app/features/calendar/presentation/screens/guardian_official_result_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

GuardianOfficialResult result(String outcome) =>
    GuardianOfficialResult.fromMap({
      'match_id': 'match',
      'name': 'Lig',
      'sport_code': 'tenis',
      'version': 1,
      'current_version': 2,
      'starts_at': '2026-10-10T12:00Z',
      'result': '2–0',
      'scores': [
        {'label': 'Set 1', 'home': 6, 'away': 2}
      ],
      'child_name': 'Çocuk',
      'outcome': outcome,
    });
void main() {
  testWidgets(
      'calendar card survives notification deletion and opens current child result',
      (t) async {
    String? route;
    final entry = GuardianCalendarResult.fromMap({
      'notification_id': null,
      'child_id': 'child',
      'child_name': 'Çocuk',
      'summary': {
        'match_id': 'match',
        'name': 'Lig',
        'sport_code': 'tenis',
        'version': 2,
        'current_version': 2,
        'outcome': 'lost',
        'scores': <Map<String, dynamic>>[]
      }
    });
    await t.pumpWidget(ProviderScope(
        overrides: [
          guardianMatchResultProvider((matchId: 'match', childId: 'child'))
              .overrideWith((_) async => result('lost'))
        ],
        child: MaterialApp(
            theme: SwanTheme.light(),
            home: Scaffold(body: GuardianCalendarResultCard(entry: entry)),
            onGenerateRoute: (settings) {
              route = settings.name;
              return MaterialPageRoute<void>(
                  builder: (_) => const GuardianOfficialResultScreen(
                      matchId: 'match', childId: 'child'));
            })));
    await t.tap(find.text('Çocuk · Lig'));
    await t.pumpAndSettle();
    expect(route, '/resmi-sonuc?match=match&child=child');
    expect(find.text('Resmi Müsabaka Karnesi'), findsOneWidget);
    expect(find.text('Mağlubiyet'), findsOneWidget);
  });
  for (final level in [1, 2, 3]) {
    testWidgets('level $level official roster lock visibility', (t) async {
      await t.pumpWidget(ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'coach',
                coachLevel: 5,
                athleteKind: null,
                sportCredentials: [
                  CredentialRow(
                      id: 'c',
                      kind: 'coach',
                      status: 'approved',
                      sportCode: 'tenis',
                      coachLevel: level)
                ])),
            officialTeamRostersProvider('team').overrideWith((_) async => [
                  OfficialTeamRoster.fromMap({
                    'participant_id': 'p',
                    'name': 'U16 Lig',
                    'sport_code': 'tenis',
                    'version': 1,
                    'athlete_ids': ['child']
                  })
                ]),
          ],
          child: MaterialApp(
              theme: SwanTheme.light(),
              home:
                  const Scaffold(body: OfficialTeamRosters(teamId: 'team')))));
      await t.pumpAndSettle();
      expect(find.text('U16 Lig'), findsOneWidget);
      expect(find.text('Kadroyu kilitle'),
          level >= 3 ? findsOneWidget : findsNothing);
      expect(find.byIcon(Icons.lock_outline_rounded),
          level < 3 ? findsOneWidget : findsNothing);
    });
  }
  testWidgets(
      'guardian private result card is immutable, displays correction/source',
      (t) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          guardianNotificationResultProvider('n')
              .overrideWith((_) async => result('won'))
        ],
        child: MaterialApp(
            theme: SwanTheme.light(),
            home: const GuardianOfficialResultScreen(notificationId: 'n'))));
    await t.pumpAndSettle();
    expect(find.text('Çocuk'), findsOneWidget);
    expect(find.text('Galibiyet'), findsOneWidget);
    expect(find.text('Set 1: 6–2'), findsOneWidget);
    expect(find.textContaining('Daha yeni'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
  });
  testWidgets('lost/draw/DQ/DNF use explicit outcome labels', (t) async {
    for (final outcome in ['lost', 'draw', 'dq', 'dnf']) {
      final r = result(outcome);
      await t.pumpWidget(MaterialApp(
          theme: SwanTheme.light(),
          home: Scaffold(body: GuardianResultBadge(result: r))));
      expect(find.text(r.outcomeLabel), findsOneWidget);
    }
  });
  testWidgets('private denial does not show child identity or result',
      (t) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          guardianNotificationResultProvider('n')
              .overrideWith((_) async => throw StateError('denied'))
        ],
        child: MaterialApp(
            theme: SwanTheme.light(),
            home: const GuardianOfficialResultScreen(notificationId: 'n'))));
    await t.pumpAndSettle();
    expect(find.text('Bu resmi sonuç görüntülenemiyor.'), findsOneWidget);
    expect(find.text('Çocuk'), findsNothing);
  });
  testWidgets('calendar result tap opens exact notification target', (t) async {
    String? target;
    final entry = GuardianCalendarResult.fromMap({
      'notification_id': 'n',
      'child_name': 'Çocuk',
      'summary': {
        'match_id': 'm',
        'name': 'Lig',
        'sport_code': 'tenis',
        'version': 1,
        'current_version': 1,
        'outcome': 'lost',
        'scores': <Map<String, dynamic>>[]
      }
    });
    await t.pumpWidget(MaterialApp(
        theme: SwanTheme.light(),
        home: Scaffold(body: GuardianCalendarResultCard(entry: entry)),
        onGenerateRoute: (s) {
          target = s.name;
          return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Target')));
        }));
    await t.tap(find.text('Çocuk · Lig'));
    await t.pumpAndSettle();
    expect(target, '/resmi-sonuc?notification=n');
  });
}

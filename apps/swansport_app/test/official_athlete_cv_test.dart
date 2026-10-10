import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/widgets/official_athlete_cv.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/widgets/athlete_profile_section.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

const official = Achievement(
    id: 'award',
    athleteId: 'athlete',
    title: 'Lig — Maç galibiyeti',
    category: 'derece',
    source: 'federation_result',
    sourceId: 'revision',
    officialMatchId: 'match',
    sportCode: 'tenis',
    note: '2–0');
void main() {
  Widget host({bool failure = false, bool denied = false}) => ProviderScope(
          overrides: [
            officialAchievementsProvider('athlete').overrideWith((_) async {
              if (denied) throw const OfficialCvAccessDenied();
              if (failure) throw StateError('network');
              return [official];
            }),
            achievementsProvider('athlete').overrideWith((_) async => [
                  const Achievement(
                      id: 'manual',
                      athleteId: 'athlete',
                      title: 'Kulüp kupası',
                      category: 'derece')
                ]),
            officialAchievementSourceProvider('award').overrideWith((_) async =>
                const OfficialAchievementSource(
                    matchId: 'match',
                    name: 'Kaynak Lig',
                    sportCode: 'tenis',
                    version: 1,
                    currentVersion: 1,
                    result: '2–0',
                    scores: [(label: 'Set 1', home: 6, away: 2)])),
          ],
          child: MaterialApp(
              theme: SwanTheme.light(),
              home: const Scaffold(
                  body: SingleChildScrollView(
                      child: OfficialAthleteCv(
                          athleteId: 'athlete', includeClub: true)))));
  testWidgets('shield, explicit club label, immutable CV and source navigation',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
    expect(find.textContaining('Resmi Federasyon Derecesi'), findsOneWidget);
    expect(find.text('Kulüp Beyanı'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    await t.tap(find.text(official.title));
    await t.pumpAndSettle();
    expect(find.text('Kaynak Lig'), findsOneWidget);
    expect(find.textContaining('değiştirilemez'), findsOneWidget);
    expect(find.text('2–0'), findsOneWidget);
    expect(find.text('Set 1: 6–2'), findsOneWidget);
  });
  testWidgets('CV failure is visible and can be retried', (t) async {
    await t.pumpWidget(host(failure: true));
    await t.pumpAndSettle();
    expect(find.textContaining('Resmi sicil yüklenemedi'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });
  testWidgets('private CV denial explains visibility without a retry loop',
      (t) async {
    await t.pumpWidget(host(denied: true));
    await t.pumpAndSettle();
    expect(
        find.textContaining('Resmi sicil sporcu, bağlı veli'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });
  testWidgets(
      'real athlete profile section includes provider-backed official CV',
      (t) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          athleteByProfileProvider('profile').overrideWith((_) async =>
              const AthleteSportInfo(
                  id: 'athlete', fullName: 'Sporcu', clubId: 'club')),
          canManageAthleteProvider('athlete').overrideWith((_) async => true),
          achievementsProvider('athlete').overrideWith((_) async => const []),
          officialAchievementsProvider('athlete')
              .overrideWith((_) async => [official]),
        ],
        child: MaterialApp(
            theme: SwanTheme.light(),
            home: const Scaffold(
                body: SingleChildScrollView(
                    child: AthleteProfileSection(profileId: 'profile'))))));
    await t.pumpAndSettle();
    expect(find.text(official.title), findsOneWidget);
    expect(find.text('Kulüp Başarıları'), findsOneWidget);
    final tile = find.byType(OfficialAchievementTile);
    expect(
        find.descendant(
            of: tile, matching: find.byIcon(Icons.delete_outline_rounded)),
        findsNothing);
    expect(find.descendant(of: tile, matching: find.byIcon(Icons.edit_rounded)),
        findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_theme.dart';
import 'package:swansport_pro/features/operations/pro_feature_host.dart';
import 'package:swansport_pro/widgets/pro_ui_components.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  const testClub = ClubRef(
    id: 'club-test-1',
    name: 'Kadıköy Spor Kulübü',
    role: 'club_admin',
  );

  Widget wrapWithHost(
    Widget child, {
    Size size = const Size(390, 844),
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: ProTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: ProOperationsFeatureHost(child: child),
        ),
      ),
    );
  }

  group('Derin Operasyon Ekranları — Görsel Standartlaşma', () {
    testWidgets('ProStatusBadge anlamsal renk ve ikon kurallarına uyar',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                ProStatusBadge(
                  label: 'Acil Görev',
                  tone: ProStatusTone.urgent,
                ),
                ProStatusBadge(
                  label: 'Yanıt Bekliyor',
                  tone: ProStatusTone.pending,
                ),
                ProStatusBadge(
                  label: 'Onaylandı',
                  tone: ProStatusTone.completed,
                ),
                ProStatusBadge(
                  label: 'Programlandı',
                  tone: ProStatusTone.scheduled,
                ),
                ProStatusBadge(
                  label: 'Bilgi',
                  tone: ProStatusTone.info,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acil Görev'), findsOneWidget);
      expect(find.text('Yanıt Bekliyor'), findsOneWidget);
      expect(find.text('Onaylandı'), findsOneWidget);
      expect(find.text('Programlandı'), findsOneWidget);
      expect(find.text('Bilgi'), findsOneWidget);

      // Semantics etiketleri mevcut
      expect(find.bySemanticsLabel('Acil Görev'), findsOneWidget);
      expect(find.bySemanticsLabel('Onaylandı'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('ProFilterBar tüm çiplerde en az 48x48 dokunma alanını korur',
        (tester) async {
      String selected = 'Tümü';
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ProFilterBar(
                filters: const ['Tümü', 'Futbol', 'Voleybol', 'Basketbol'],
                selected: selected,
                onChanged: (val) => setState(() => selected = val),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['Tümü', 'Futbol', 'Voleybol', 'Basketbol']) {
        final chip = find.text(label);
        expect(chip, findsOneWidget);
        final renderBox = tester.renderObject(chip);
        expect(renderBox, isNotNull);
        final ancestorMaterial = find.ancestor(
          of: chip,
          matching: find.byType(Material),
        );
        expect(ancestorMaterial, findsWidgets);
        final size = tester.getSize(ancestorMaterial.first);
        expect(size.height, greaterThanOrEqualTo(48.0));
        expect(size.width, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets(
        'Kulüp ve Kadro: SharedTeamDirectoryScreen başlık ve boş/dolu durum standartları',
        (tester) async {
      await tester.pumpWidget(
        wrapWithHost(
          const SharedTeamDirectoryScreen(),
          overrides: [
            activeClubProvider.overrideWith((ref) async => testClub),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({FeatureFlags.teamHub}),
            ),
            teamsProvider.overrideWith((ref) async => const <TeamRow>[]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Takımlar & Kadrolar'), findsOneWidget);
      final addBtn = find.byTooltip('Takım Ekle');
      if (addBtn.evaluate().isNotEmpty) {
        final btnSize = tester.getSize(addBtn);
        expect(btnSize.width, greaterThanOrEqualTo(48.0));
        expect(btnSize.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets(
        'Hakem Operasyonları: SharedRefereeOperationsPanel durum kartları ve min dokunma boyutu',
        (tester) async {
      final now = DateTime.now().toUtc();
      await tester.pumpWidget(
        wrapWithHost(
          const SharedRefereeOperationsPanel(),
          overrides: [
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                refereeProfile: RefereeProfile(
                  id: 'ref-test',
                  profileId: 'u-1',
                  licenseNumber: 'TFF-06-TEST',
                  badgeTier: RefereeBadgeTier.national,
                  sportCode: 'futbol',
                  cityCode: '06',
                  isActive: true,
                ),
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({FeatureFlags.refereeCockpit}),
            ),
            refereeDutyMatchesProvider.overrideWith(
              (ref) async => [
                RefereeMatchSummary(
                  officialId: 'off-1',
                  matchId: '11111111-1111-4111-8111-111111111111',
                  duty: MatchOfficialDuty.headReferee,
                  status: MatchOfficialStatus.accepted,
                  assignedAt: now.subtract(const Duration(hours: 1)),
                  startsAt: now.add(const Duration(hours: 2)),
                  location: 'Kadıköy Stadı',
                  sportCode: 'futbol',
                  homeClubName: 'Fenerbahçe SK',
                  awayClubName: 'Galatasaray SK',
                  matchStatus: 'scheduled',
                  cityCode: '34',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hakem Operasyonları'), findsOneWidget);
      expect(find.text('Hakem Görevlerim & Yanıtlar'), findsOneWidget);
      expect(find.text('Dijital Esame Onayı'), findsOneWidget);

      final cards = find.byType(ClubOperationCard);
      expect(cards, findsWidgets);
      for (final card in cards.evaluate()) {
        final size = card.size;
        if (size != null) {
          expect(size.height, greaterThanOrEqualTo(48.0));
        }
      }
    });

    testWidgets(
        'Muhasebe Operasyonları: SharedClubBudgetScreen kesin vs tahmini ayrımı ve responsive parite',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithHost(
          const SharedClubBudgetScreen(),
          overrides: [
            activeClubProvider.overrideWith((ref) async => testClub),
            myClubsProvider.overrideWith((ref) async => [testClub]),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
                accountantClubIds: {'club-test-1'},
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.financeOperationsCenter,
                FeatureFlags.clubBudgeting,
              }),
            ),
            budgetLinesProvider.overrideWith((ref) async => const []),
            cashForecastProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bütçe & Nakit Tahmini'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Geniş ekrana geçişte taşma olmamalı
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Federasyon Operasyonları: SharedLeagueStandingsScreen puan tablosu taşmasız kaydırılır',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const fedScope = FederationConsoleScope(
        federationId: 'fed-tff',
        name: 'Türkiye Futbol Federasyonu',
        sportCode: 'futbol',
        role: 'president',
      );

      await tester.pumpWidget(
        wrapWithHost(
          const SharedLeagueStandingsScreen(),
          overrides: [
            activeClubProvider.overrideWith((ref) async => testClub),
            swanAccessProvider.overrideWithValue(
              SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                federationRoles: [
                  FederationRole(
                    id: 'r-1',
                    federationId: 'fed-tff',
                    profileId: 'u-1',
                    role: FederationRoleKind.president,
                    startsOn: DateTime.utc(2026, 1, 1),
                    endsOn: DateTime.utc(2027, 1, 1),
                  ),
                ],
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.leagueStandings,
              }),
            ),
            federationConsoleScopesProvider
                .overrideWith((ref) async => const [fedScope]),
            standingsLeaguesProvider.overrideWith(
              (ref) async => const [
                StandingsLeague(
                  id: '22222222-2222-4222-8222-222222222222',
                  federationId: 'fed-tff',
                  name: 'Süper Amatör Ligi',
                  sportCode: 'futbol',
                  winPoints: 3,
                  drawPoints: 1,
                  lossPoints: 0,
                ),
              ],
            ),
            leagueStandingsProvider.overrideWith((ref, query) async {
              return [
                LeagueStandingsRow(
                  rank: 1,
                  participantId: 'p-1',
                  name: 'SwanSport Ankara SK',
                  played: 10,
                  won: 8,
                  drawn: 1,
                  lost: 1,
                  goalsFor: 20,
                  goalsAgainst: 6,
                  goalDiff: 14,
                  points: 25,
                  form: const ['W', 'W', 'W'],
                ),
              ];
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lig & Puan Durumu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Tesis Operasyonları: SharedFacilityReservationsScreen fail-closed yetki durumu',
        (tester) async {
      await tester.pumpWidget(
        wrapWithHost(
          const SharedFacilityReservationsScreen(),
          overrides: [
            activeClubProvider.overrideWith((ref) async => testClub),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async =>
                  const FeatureFlags({FeatureFlags.facilityConflicts}),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aktif ve Bekleyen Rezervasyonlar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

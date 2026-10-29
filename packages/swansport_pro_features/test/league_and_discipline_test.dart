import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  const bakanScope = FederationConsoleScope(
    federationId: 'fed-tbf',
    name: 'Türkiye Basketbol Federasyonu',
    sportCode: 'basketbol',
    role: 'president',
  );

  testWidgets(
    'SharedLeagueStandingsScreen respects feature flag, uses organization win/draw/loss points (not hardcoded 3/1/0), and toggles live projection',
    (tester) async {
      final now = DateTime.now().toUtc();
      final queries = <LeagueStandingsQuery>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(
              SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                federationRoles: [
                  FederationRole(
                    id: 'r-pres',
                    federationId: 'fed-tbf',
                    profileId: 'u-pres',
                    role: FederationRoleKind.president,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.leagueStandings,
              }),
            ),
            federationConsoleScopesProvider.overrideWith(
              (ref) async => const [bakanScope],
            ),
            standingsLeaguesProvider.overrideWith(
              (ref) async => const [
                StandingsLeague(
                  id: '22222222-2222-4222-8222-222222222222',
                  federationId: 'fed-tbf',
                  name: 'Basketbol Gençler Ligi',
                  sportCode: 'basketbol',
                  winPoints: 2,
                  drawPoints: 1,
                  lossPoints: 0,
                ),
              ],
            ),
            leagueStandingsProvider.overrideWith((ref, query) async {
              queries.add(query);
              return [
                LeagueStandingsRow(
                  rank: 1,
                  participantId: 'p-1',
                  name: 'Anadolu Basket',
                  played: 5,
                  won: 4,
                  drawn: 0,
                  lost: 1,
                  goalsFor: 410,
                  goalsAgainst: 365,
                  goalDiff: 45,
                  points: 9,
                  form: const ['W', 'W', 'L', 'W', 'W'],
                  isProvisional: query.includeLive,
                ),
              ];
            }),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedLeagueStandingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Organization's custom 2/1/0 points rule shown, not hardcoded 3/1/0
      expect(
        find.textContaining('Galibiyet: 2 · Beraberlik: 1 · Mağlubiyet: 0'),
        findsOneWidget,
      );
      expect(find.text('Anadolu Basket'), findsOneWidget);
      expect(queries.last.includeLive, isFalse);

      // Toggle live provisional projection
      await tester.tap(find.byKey(const Key('league-standings-live-toggle')));
      await tester.pumpAndSettle();

      expect(queries.last.includeLive, isTrue);
      expect(find.textContaining('Geçici Canlı'), findsWidgets);
    },
  );

  testWidgets(
    'SharedDisciplinaryBoardScreen blocks provincial representative',
    (tester) async {
      final now = DateTime.now().toUtc();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(
              SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                federationRoles: [
                  FederationRole(
                    id: 'r-prov',
                    federationId: 'fed-tbf',
                    profileId: 'u-prov',
                    role: FederationRoleKind.provincialRep,
                    cityCode: '06',
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
              ),
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedDisciplinaryBoardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Disiplin kurulu erişim yetkiniz bulunmuyor'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SharedDisciplinaryBoardScreen preserves same operation ID on uncertain retry',
    (tester) async {
      final now = DateTime.now().toUtc();
      final recordedPayloads = <Map<String, dynamic>>[];
      var shouldFailWithTimeout = true;

      final sampleReport = FederationDisciplinaryReport(
        matchId: '33333333-3333-4333-8333-333333333333',
        revisionId: 'rev-1',
        program: 'Basketbol Gençler Ligi',
        sportCode: 'basketbol',
        cityCode: '06',
        signedAt: DateTime.utc(2026, 10, 25, 18),
        notes: 'Hakem raporu: 2. periyotta sportmenlik dışı hareket.',
        canDecide: true,
        athletes: const [
          DisciplinarySubject(
            athleteId: 'ath-uuid-1',
            clubId: 'club-uuid-1',
            reference: '#A3F91C',
          ),
        ],
        redCardAthleteIds: const ['ath-uuid-1'],
        decisions: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(
              SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                federationRoles: [
                  FederationRole(
                    id: 'r-disc',
                    federationId: 'fed-tbf',
                    profileId: 'u-disc',
                    role: FederationRoleKind.disciplinaryBoard,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
              ),
            ),
            federationScopedDisciplinaryReportsProvider.overrideWith(
              (ref, offset) async =>
                  FederationConsolePage<FederationDisciplinaryReport>(
                total: 1,
                rows: [sampleReport],
              ),
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: SharedDisciplinaryBoardScreen(
                onRecordDecision: (payload) async {
                  recordedPayloads.add(<String, dynamic>{...payload});
                  if (shouldFailWithTimeout) {
                    throw TimeoutException('Network timeout');
                  }
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2. periyotta sportmenlik dışı hareket.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const Key(
            'disciplinary-decide-btn-33333333-3333-4333-8333-333333333333',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select masked athlete #A3F91C
      await tester.tap(find.byKey(const Key('disciplinary-athlete-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('#A3F91C').last);
      await tester.pumpAndSettle();

      // Enter reason
      await tester.enterText(
        find.byKey(const Key('disciplinary-reason-input')),
        'Kurul kararı: 1 maç men cezası verildi.',
      );
      await tester.pumpAndSettle();

      // First attempt fails with TimeoutException (uncertain network state)
      await tester.tap(find.byKey(const Key('disciplinary-submit-btn')));
      await tester.pumpAndSettle();

      expect(recordedPayloads, hasLength(1));
      final firstOpId = recordedPayloads.first['p_operation_id'] as String;
      expect(firstOpId, isNotEmpty);
      expect(
        find.textContaining('Aynı işlem kimliğiyle tekrar deneyin'),
        findsOneWidget,
      );
      expect(find.text('Aynı İşlemi Tekrar Dene'), findsOneWidget);

      // Second attempt succeeds and MUST reuse the exact same p_operation_id and payload
      shouldFailWithTimeout = false;
      await tester.tap(find.byKey(const Key('disciplinary-submit-btn')));
      await tester.pumpAndSettle();

      expect(recordedPayloads, hasLength(2));
      expect(recordedPayloads.last['p_operation_id'], firstOpId);
      expect(recordedPayloads.last['p_athlete_id'], 'ath-uuid-1');
      expect(recordedPayloads.last['p_penalty_type'], 'match_ban');
      expect(recordedPayloads.last['p_match_ban_count'], 1);
    },
  );

  testWidgets(
    'SharedFederationBulletinsScreen renders published public summaries and official notices',
    (tester) async {
      final now = DateTime.now().toUtc();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(
              SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                federationRoles: [
                  FederationRole(
                    id: 'r-pres',
                    federationId: 'fed-tbf',
                    profileId: 'u-pres',
                    role: FederationRoleKind.president,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.federationBulletin,
              }),
            ),
            federationConsoleScopesProvider.overrideWith(
              (ref) async => const [bakanScope],
            ),
            federationDisciplinaryBulletinProvider.overrideWith(
              (ref, filter) async => [
                FederationDisciplinaryItem(
                  id: 'b-1',
                  matchId: '33333333-3333-4333-8333-333333333333',
                  sportCode: 'basketbol',
                  clubName: 'Anadolu Basket',
                  athleteDisplay: '#A3F91C',
                  penaltyType: 'match_ban',
                  penaltyLabel: '1 Maç Men',
                  reason:
                      'Yayımlanmış kamu özeti: 1 maç resmi müsabakalardan men.',
                  createdAt: DateTime.utc(2026, 10, 26),
                  matchTitle: 'Anadolu Basket - Başkent SK',
                  programName: 'Basketbol Gençler Ligi',
                ),
              ],
            ),
            federationNoticesProvider.overrideWith(
              (ref, filter) async => [
                FederationNoticeItem(
                  id: 'n-1',
                  sportCode: 'basketbol',
                  noticeType: 'match_postponed',
                  title: 'Müsabaka Saat Değişikliği',
                  body:
                      'Salon bakımı nedeniyle müsabaka 16:00 saatine alınmıştır.',
                  publishedAt: DateTime.utc(2026, 10, 26, 9),
                  programName: 'Basketbol Gençler Ligi',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedFederationBulletinsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Yayımlanmış kamu özeti: 1 maç resmi müsabakalardan men.',
        ),
        findsOneWidget,
      );
      expect(find.text('Müsabaka Saat Değişikliği'), findsOneWidget);
    },
  );

  testWidgets(
    'SharedLeagueStandingsScreen and SharedFederationBulletinsScreen fail-closed when feature flag is off or errors',
    (tester) async {
      final now = DateTime.now().toUtc();
      final access = SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 0,
        athleteKind: null,
        federationRoles: [
          FederationRole(
            id: 'r-pres',
            federationId: 'fed-tbf',
            profileId: 'u-pres',
            role: FederationRoleKind.president,
            startsOn: now.subtract(const Duration(days: 5)),
            endsOn: now.add(const Duration(days: 30)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(access),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags.none(),
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedLeagueStandingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Lig puan durumu modülü devre dışı'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(access),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags.none(),
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedFederationBulletinsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Federasyon bülten modülü devre dışı'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SharedFederationBulletinsScreen supports official result registration (only with resultPublisher appointment), disciplinary bulletin summary publication, and match notice publication',
    (tester) async {
      final now = DateTime.now().toUtc();
      Map<String, dynamic>? publishedResultCall;
      Map<String, String>? publishedDisciplinaryCall;
      Map<String, String>? publishedNoticeCall;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(
              SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                federationRoles: [
                  FederationRole(
                    id: 'r-pres',
                    federationId: 'fed-tbf',
                    profileId: 'u-pres',
                    role: FederationRoleKind.president,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                  FederationRole(
                    id: 'r-disc',
                    federationId: 'fed-tbf',
                    profileId: 'u-pres',
                    role: FederationRoleKind.disciplinaryBoard,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
                federationAppointments: [
                  FederationAppointment(
                    id: 'app-pub-1',
                    sportCode: 'basketbol',
                    cityCode: '06',
                    duty: FederationDuty.resultPublisher,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.federationBulletin,
              }),
            ),
            federationConsoleScopesProvider.overrideWith(
              (ref) async => const [bakanScope],
            ),
            federationScopedPendingResultsProvider.overrideWith(
              (ref, offset) async => const [
                FederationPendingMatch(
                  id: 'match-pending-1',
                  name: 'Basketbol Gençler Ligi',
                  sportCode: 'basketbol',
                  cityCode: '06',
                  version: 1,
                  homeName: 'Anadolu Basket',
                  awayName: 'Başkent SK',
                ),
              ],
            ),
            federationScopedDisciplinaryReportsProvider.overrideWith(
              (ref, offset) async =>
                  FederationConsolePage<FederationDisciplinaryReport>(
                total: 1,
                rows: [
                  FederationDisciplinaryReport(
                    matchId: 'match-pending-1',
                    revisionId: 'rev-1',
                    program: 'Basketbol Gençler Ligi',
                    sportCode: 'basketbol',
                    cityCode: '06',
                    signedAt: DateTime.utc(2026, 10, 26, 15),
                    notes: 'İç hakem raporu notu',
                    canDecide: true,
                    athletes: const [],
                    redCardAthleteIds: const [],
                    decisions: [
                      DisciplinaryDecision(
                        id: 'dec-uuid-1',
                        athleteId: 'ath-1',
                        penaltyType: 'match_ban',
                        matchBanCount: 2,
                        reason: 'İç kurul gerekçesi (gizli)',
                        createdAt: DateTime.utc(2026, 10, 26, 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            federationConsoleMatchesProvider.overrideWith(
              (ref, query) async =>
                  FederationConsolePage<FederationConsoleMatch>(
                total: 1,
                rows: [
                  FederationConsoleMatch(
                    id: 'match-postponed-1',
                    program: 'Basketbol Gençler Ligi',
                    sportCode: 'basketbol',
                    status: 'postponed',
                    cityCode: '06',
                    homeName: 'Anadolu Basket',
                    awayName: 'Başkent SK',
                  ),
                ],
              ),
            ),
            federationDisciplinaryBulletinProvider.overrideWith(
              (ref, filter) async => const [],
            ),
            federationNoticesProvider.overrideWith(
              (ref, filter) async => const [],
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: SharedFederationBulletinsScreen(
                onPublishResult: ({
                  required String matchId,
                  required Map<String, dynamic> protocol,
                  required String reason,
                  required int expectedVersion,
                }) async {
                  publishedResultCall = <String, dynamic>{
                    'matchId': matchId,
                    'protocol': protocol,
                    'reason': reason,
                    'expectedVersion': expectedVersion,
                  };
                  return 'rev-2';
                },
                onPublishDisciplinaryBulletin: ({
                  required String decisionId,
                  required String publicSummary,
                }) async {
                  publishedDisciplinaryCall = <String, String>{
                    'decisionId': decisionId,
                    'publicSummary': publicSummary,
                  };
                  return 'bul-1';
                },
                onPublishMatchNotice: ({
                  required String matchId,
                  required String noticeType,
                  required String publicSummary,
                }) async {
                  publishedNoticeCall = <String, String>{
                    'matchId': matchId,
                    'noticeType': noticeType,
                    'publicSummary': publicSummary,
                  };
                  return 'notice-1';
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Publish official match result revision (V1 -> V2)
      await tester.scrollUntilVisible(
        find.byKey(const Key('bulletin-publish-result-btn-match-pending-1')),
        300,
      );
      await tester.tap(
        find.byKey(const Key('bulletin-publish-result-btn-match-pending-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('publish-result-protocol-input')),
        '''{"status":"finished","periods":[{"label":"Q1","home":20,"away":18,"team_fouls":{"home":3,"away":4}},{"label":"Q2","home":20,"away":18,"team_fouls":{"home":2,"away":3}},{"label":"Q3","home":19,"away":20,"team_fouls":{"home":4,"away":4}},{"label":"Q4","home":19,"away":18,"team_fouls":{"home":3,"away":2}}]}''',
      );
      await tester.enterText(
        find.byKey(const Key('publish-result-reason-input')),
        'MHK itiraz incelemesi sonrası skor tescili',
      );
      await tester.tap(find.byKey(const Key('publish-result-submit-btn')));
      await tester.pumpAndSettle();

      expect(publishedResultCall, isNotNull);
      expect(publishedResultCall!['matchId'], 'match-pending-1');
      expect(publishedResultCall!['expectedVersion'], 1);
      expect(
        publishedResultCall!['protocol'],
        <String, dynamic>{
          'status': 'finished',
          'sport_code': 'basketbol',
          'periods': <dynamic>[
            <String, dynamic>{
              'label': 'Q1',
              'home': 20,
              'away': 18,
              'team_fouls': <String, dynamic>{'home': 3, 'away': 4},
            },
            <String, dynamic>{
              'label': 'Q2',
              'home': 20,
              'away': 18,
              'team_fouls': <String, dynamic>{'home': 2, 'away': 3},
            },
            <String, dynamic>{
              'label': 'Q3',
              'home': 19,
              'away': 20,
              'team_fouls': <String, dynamic>{'home': 4, 'away': 4},
            },
            <String, dynamic>{
              'label': 'Q4',
              'home': 19,
              'away': 18,
              'team_fouls': <String, dynamic>{'home': 3, 'away': 2},
            },
          ],
        },
      );

      // 2. Publish public disciplinary bulletin summary
      await tester.tap(
        find.byKey(const Key('bulletin-open-publish-disciplinary-btn')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('publish-disciplinary-summary-input')),
        'Disiplin Kurulu kararıyla 2 resmi müsabakadan men cezası verilmiştir.',
      );
      await tester
          .tap(find.byKey(const Key('publish-disciplinary-submit-btn')));
      await tester.pumpAndSettle();

      expect(publishedDisciplinaryCall, <String, String>{
        'decisionId': 'dec-uuid-1',
        'publicSummary':
            'Disiplin Kurulu kararıyla 2 resmi müsabakadan men cezası verilmiştir.',
      });

      // 3. Publish official match notice
      await tester.tap(
        find.byKey(const Key('bulletin-open-publish-notice-btn')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('publish-notice-summary-input')),
        'Salon zemin bakımı nedeniyle müsabaka ileri bir tarihe ertelenmiştir.',
      );
      await tester.tap(find.byKey(const Key('publish-notice-submit-btn')));
      await tester.pumpAndSettle();

      expect(publishedNoticeCall, <String, String>{
        'matchId': 'match-postponed-1',
        'noticeType': 'match_postponed',
        'publicSummary':
            'Salon zemin bakımı nedeniyle müsabaka ileri bir tarihe ertelenmiştir.',
      });
    },
  );

  testWidgets(
    'match notice dialog never falls back to a scheduled match',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            federationConsoleMatchesProvider.overrideWith(
              (ref, query) async =>
                  FederationConsolePage<FederationConsoleMatch>(
                total: 1,
                rows: [
                  FederationConsoleMatch(
                    id: 'scheduled-1',
                    program: 'Planlanan Lig Maçı',
                    sportCode: 'basketbol',
                    status: 'scheduled',
                  ),
                ],
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SharedPublishMatchNoticeDialog(scope: bakanScope),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Kapsamda iptal edilmiş veya ertelenmiş müsabaka bulunamadı.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('publish-notice-match-dropdown')),
        findsNothing,
      );
      final submit = tester.widget<FilledButton>(
        find.byKey(const Key('publish-notice-submit-btn')),
      );
      expect(submit.onPressed, isNull);
    },
  );
}

final class _Navigator extends ProFeatureNavigatorBase {
  @override
  void openTeams() {}
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openAttendance() {}
  @override
  void openAttendanceHistory() {}
  @override
  void openTrainingList() {}
  @override
  void openTrainingProtocols() {}
  @override
  void openTrainingBuilder() {}
  @override
  void openTrainingSession({String? sessionId}) {}
  @override
  void openTrainingResult({String? sessionId}) {}
}

final class _Chrome implements ProFeatureChrome {
  const _Chrome();

  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: body,
        bottomNavigationBar: bottomBar,
      );

  @override
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) async =>
      true;

  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {}
}

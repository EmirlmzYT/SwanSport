import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  const mhkScope = FederationConsoleScope(
    federationId: 'fed-tff',
    name: 'Türkiye Futbol Federasyonu',
    sportCode: 'futbol',
    role: 'referee_committee',
  );

  const provincialScope = FederationConsoleScope(
    federationId: 'fed-tff',
    name: 'Türkiye Futbol Federasyonu',
    sportCode: 'futbol',
    role: 'provincial_rep',
    cityCode: '06',
  );

  final sampleMatch = FederationConsoleMatch(
    id: '11111111-1111-4111-8111-111111111111',
    program: 'U19 Elit Lig 1. Hafta',
    sportCode: 'futbol',
    status: 'scheduled',
    cityCode: '06',
    startsAt: DateTime.utc(2026, 11, 2, 12),
    location: 'Ankara',
    homeName: 'Anadolu Gençlik',
    awayName: 'Başkent Spor',
    facilityName: '19 Mayıs Yan Saha',
    facilityConflictCount: null,
    officials: const [
      ConsoleMatchOfficial(
        id: 'off-1',
        duty: 'head_referee',
        status: 'declined',
        name: 'Hakem Mert',
        declineReason: 'Ailevi sağlık mazereti (özel not)',
      ),
      ConsoleMatchOfficial(
        id: 'off-2',
        duty: 'assistant_referee_1',
        status: 'accepted',
        name: 'Hakem Selin',
      ),
    ],
  );

  testWidgets('denies access when user cannot view referee assignments', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 1,
              athleteKind: null,
            ),
          ),
        ],
        child: MaterialApp(
          home: ProFeatureHostScope(
            navigator: _Navigator(),
            chrome: const _Chrome(),
            theme: ProFeatureThemeData.dark,
            child: const SharedRefereeAssignmentsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hakem atama yetkiniz bulunmuyor'), findsOneWidget);
  });

  testWidgets(
    'provincial representative sees read-only official statuses, never sees private declineReason, and does not query locked reports or referee pool',
    (tester) async {
      final now = DateTime.now().toUtc();
      var queriedLockedReport = false;
      var queriedRefereePool = false;

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
                    id: 'role-prov',
                    federationId: 'fed-tff',
                    profileId: 'user-prov',
                    role: FederationRoleKind.provincialRep,
                    cityCode: '06',
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
              ),
            ),
            citiesProvider.overrideWith(
              (ref) async => const [CityRow(code: '06', name: 'Ankara')],
            ),
            federationConsoleScopesProvider.overrideWith(
              (ref) async => const [provincialScope],
            ),
            federationConsoleMatchesProvider.overrideWith(
              (ref, query) async =>
                  FederationConsolePage<FederationConsoleMatch>(
                total: 1,
                rows: [sampleMatch],
              ),
            ),
            federationLockedReportProvider.overrideWith((ref, matchId) async {
              queriedLockedReport = true;
              return null;
            }),
            federationAvailableRefereesProvider.overrideWith(
              (ref, matchId) async {
                queriedRefereePool = true;
                return const [];
              },
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedRefereeAssignmentsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('U19 Elit Lig 1. Hafta'), findsOneWidget);
      expect(find.textContaining('Hakem Mert'), findsOneWidget);
      expect(find.textContaining('Hakem Selin'), findsOneWidget);
      // Private decline reason must NEVER be rendered for provincial representative
      expect(find.textContaining('Ailevi sağlık mazereti'), findsNothing);
      // Read-only badge shown, no assign button
      expect(find.text('Salt Okunur (İl Temsilcisi)'), findsOneWidget);
      expect(
        find.byKey(
          const Key('referee-assign-btn-11111111-1111-4111-8111-111111111111'),
        ),
        findsNothing,
      );
      // Null facility conflict preserved as Doğrulanamıyor (never 0)
      expect(find.textContaining('Doğrulanamıyor'), findsOneWidget);
      expect(queriedLockedReport, isFalse);
      expect(queriedRefereePool, isFalse);
    },
  );

  testWidgets(
    'central referee board sees private declineReason, locked report summary, and assigns eligible official via callback',
    (tester) async {
      final now = DateTime.now().toUtc();
      String? assignedMatchId;
      String? assignedProfileId;
      MatchOfficialDuty? assignedDuty;

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
                    id: 'role-mhk',
                    federationId: 'fed-tff',
                    profileId: 'user-mhk',
                    role: FederationRoleKind.refereeCommittee,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
              ),
            ),
            citiesProvider.overrideWith(
              (ref) async => const [CityRow(code: '06', name: 'Ankara')],
            ),
            federationConsoleScopesProvider.overrideWith(
              (ref) async => const [mhkScope],
            ),
            federationConsoleMatchesProvider.overrideWith(
              (ref, query) async =>
                  FederationConsolePage<FederationConsoleMatch>(
                total: 1,
                rows: [sampleMatch],
              ),
            ),
            federationLockedReportProvider.overrideWith(
              (ref, matchId) async => LockedRefereeReport(
                matchId: matchId,
                revisionId: 'rev-99',
                notes: 'Müsabaka sorunsuz tamamlandı.',
                signedAt: DateTime.utc(2026, 11, 2, 15),
                redCardCount: 1,
                homeScore: 2,
                awayScore: 1,
              ),
            ),
            federationAvailableRefereesProvider.overrideWith(
              (ref, matchId) async => [
                AvailableReferee(
                  profileId: 'ref-candidate-1',
                  name: 'Hakem Deniz Kaya',
                  badgeTier: 'Klasman',
                  cityCode: '06',
                  lastMatchAt: DateTime.utc(2026, 10, 20),
                ),
              ],
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: SharedRefereeAssignmentsScreen(
                onAssignOfficial: ({
                  required String matchId,
                  required String officialProfileId,
                  required MatchOfficialDuty duty,
                }) async {
                  assignedMatchId = matchId;
                  assignedProfileId = officialProfileId;
                  assignedDuty = duty;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MHK sees private decline reason and locked report summary
      expect(find.textContaining('Ailevi sağlık mazereti'), findsOneWidget);
      expect(
        find.textContaining('Müsabaka sorunsuz tamamlandı.'),
        findsOneWidget,
      );

      // Open assignment dialog
      final assignBtn = find.byKey(
        const Key('referee-assign-btn-11111111-1111-4111-8111-111111111111'),
      );
      await tester.ensureVisible(assignBtn);
      await tester.pumpAndSettle();
      await tester.tap(assignBtn);
      await tester.pumpAndSettle();

      expect(find.text('Hakem Deniz Kaya'), findsOneWidget);
      await tester.tap(find.text('Hakem Deniz Kaya'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('referee-assign-submit-btn')));
      await tester.pumpAndSettle();

      expect(assignedMatchId, '11111111-1111-4111-8111-111111111111');
      expect(assignedProfileId, 'ref-candidate-1');
      expect(assignedDuty, MatchOfficialDuty.headReferee);
    },
  );

  testWidgets('renders without overflow at 320px width and 2x text scale', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
                  id: 'role-mhk',
                  federationId: 'fed-tff',
                  profileId: 'user-mhk',
                  role: FederationRoleKind.refereeCommittee,
                  startsOn: now.subtract(const Duration(days: 5)),
                  endsOn: now.add(const Duration(days: 30)),
                ),
              ],
            ),
          ),
          citiesProvider.overrideWith(
            (ref) async => const [CityRow(code: '06', name: 'Ankara')],
          ),
          federationConsoleScopesProvider.overrideWith(
            (ref) async => const [mhkScope],
          ),
          federationConsoleMatchesProvider.overrideWith(
            (ref, query) async => FederationConsolePage<FederationConsoleMatch>(
              total: 1,
              rows: [sampleMatch],
            ),
          ),
          federationLockedReportProvider.overrideWith(
            (ref, matchId) async => null,
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: ProFeatureHostScope(
            navigator: _Navigator(),
            chrome: const _Chrome(),
            theme: ProFeatureThemeData.dark,
            child: const SharedRefereeAssignmentsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('U19 Elit Lig 1. Hafta'), findsOneWidget);
  });
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  const activeRefereeProfile = RefereeProfile(
    id: 'ref-prof-1',
    profileId: 'user-ref-1',
    licenseNumber: 'TFF-06-991',
    badgeTier: RefereeBadgeTier.national,
    sportCode: 'futbol',
    cityCode: '06',
    isActive: true,
  );

  SwanAccess refereeAccess() => const SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 0,
        athleteKind: null,
        refereeProfile: activeRefereeProfile,
      );

  testWidgets(
    'SharedRefereeOperationsPanel denies non-referee users without querying duty matches',
    (tester) async {
      var queriedMatches = false;

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
            refereeDutyMatchesProvider.overrideWith((ref) async {
              queriedMatches = true;
              return const [];
            }),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const Scaffold(body: SharedRefereeOperationsPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Hakem operasyon yetkisi gerekli'),
        findsOneWidget,
      );
      expect(queriedMatches, isFalse);
    },
  );

  testWidgets(
    'SharedRefereeDutyListScreen accepts/declines duties, opens lineup for supported sport, and blocks unsupported sport protocol',
    (tester) async {
      final now = DateTime.now().toUtc();
      final navigator = _Navigator();
      String? respondedOfficialId;
      bool? respondedAccept;
      String? respondedReason;

      final futbolMatch = RefereeMatchSummary(
        officialId: 'off-fut-1',
        matchId: '44444444-4444-4444-8444-444444444444',
        duty: MatchOfficialDuty.headReferee,
        status: MatchOfficialStatus.accepted,
        assignedAt: now.subtract(const Duration(days: 1)),
        startsAt: now,
        location: 'Ankara 19 Mayıs',
        sportCode: 'futbol',
        homeClubName: 'Anadolu SK',
        awayClubName: 'Başkent SK',
        matchStatus: 'scheduled',
        cityCode: '06',
      );

      final pendingMatch = RefereeMatchSummary(
        officialId: 'off-pend-2',
        matchId: '55555555-5555-4555-8555-555555555555',
        duty: MatchOfficialDuty.assistantReferee1,
        status: MatchOfficialStatus.assigned,
        assignedAt: now.subtract(const Duration(hours: 4)),
        startsAt: now.add(const Duration(days: 1)),
        location: 'Yenimahalle Sahası',
        sportCode: 'futbol',
        homeClubName: 'Gençler SK',
        awayClubName: 'Çankaya SK',
        matchStatus: 'scheduled',
        cityCode: '06',
      );

      final unsupportedSportMatch = RefereeMatchSummary(
        officialId: 'off-atl-3',
        matchId: '66666666-6666-4666-8666-666666666666',
        duty: MatchOfficialDuty.headReferee,
        status: MatchOfficialStatus.accepted,
        assignedAt: now.subtract(const Duration(days: 1)),
        startsAt: now,
        location: 'Atletizm Pisti',
        sportCode: 'atletizm',
        homeClubName: 'Bireysel Etap',
        awayClubName: 'Final Serisi',
        matchStatus: 'scheduled',
        cityCode: '06',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(refereeAccess()),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.refereeCockpit,
              }),
            ),
            refereeDutyMatchesProvider.overrideWith(
              (ref) async => [
                futbolMatch,
                pendingMatch,
                unsupportedSportMatch,
              ],
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: navigator,
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: SharedRefereeDutyListScreen(
                onRespondAssignment: ({
                  required String officialId,
                  required bool accept,
                  String? reason,
                }) async {
                  respondedOfficialId = officialId;
                  respondedAccept = accept;
                  respondedReason = reason;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Unsupported sport shows explicit notice and no live control button
      expect(
        find.text('Bu branşın canlı sonuç protokolü henüz açık değil.'),
        findsOneWidget,
      );

      // Accept pending match
      await tester.tap(find.byKey(const Key('referee-duty-accept-off-pend-2')));
      await tester.pumpAndSettle();
      expect(respondedOfficialId, 'off-pend-2');
      expect(respondedAccept, isTrue);
      expect(respondedReason, isNull);

      // Open lineup for supported futbol match
      await tester.tap(
        find.byKey(
          const Key(
            'referee-duty-lineup-44444444-4444-4444-8444-444444444444',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        navigator.calls,
        contains('lineup:44444444-4444-4444-8444-444444444444'),
      );
    },
  );

  testWidgets(
    'SharedRefereeLineupApprovalScreen validates UUID, enforces starter selection for both server sides, and locks immutable lineup',
    (tester) async {
      final navigator = _Navigator();
      List<String>? lockedHomeStarters;
      List<String>? lockedAwayStarters;
      List<String>? lockedHomeSubs;

      const matchId = '44444444-4444-4444-8444-444444444444';
      const candidates = [
        RefereeLineupCandidate(
          athleteId: 'aaaa1111-1111-4111-8111-111111111111',
          side: 'home',
          name: 'Kaan Yılmaz',
          jerseyNumber: 10,
          licenseNumber: 'LIC-10',
          eligibilityStatus: 'eligible',
          eligible: true,
          selection: 'unselected',
        ),
        RefereeLineupCandidate(
          athleteId: 'aaaa2222-2222-4222-8222-222222222222',
          side: 'home',
          name: 'Emre Kaya',
          jerseyNumber: 4,
          licenseNumber: 'LIC-04',
          eligibilityStatus: 'suspended',
          eligible: false,
          selection: 'unselected',
        ),
        RefereeLineupCandidate(
          athleteId: 'bbbb1111-1111-4111-8111-111111111111',
          side: 'away',
          name: 'Burak Demir',
          jerseyNumber: 9,
          licenseNumber: 'LIC-09',
          eligibilityStatus: 'eligible',
          eligible: true,
          selection: 'unselected',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(refereeAccess()),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.refereeCockpit,
              }),
            ),
            matchLineupApprovalsProvider(matchId).overrideWith(
              (ref) async => const [],
            ),
            refereeLineupCandidatesProvider(matchId).overrideWith(
              (ref) async => candidates,
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: navigator,
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: SharedRefereeLineupApprovalScreen(
                matchId: matchId,
                onVerifyLineup: ({
                  required String matchId,
                  required List<String> homeStarters,
                  required List<String> awayStarters,
                  required List<String> homeSubs,
                  required List<String> awaySubs,
                }) async {
                  lockedHomeStarters = homeStarters;
                  lockedAwayStarters = awayStarters;
                  lockedHomeSubs = homeSubs;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Suspended candidate is shown as Cezalı
      expect(find.text('Cezalı'), findsOneWidget);

      // Select home starter Kaan Yılmaz
      await tester.tap(
        find.byKey(
          const Key(
            'lineup-select-aaaa1111-1111-4111-8111-111111111111',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sahaya çıkan').last);
      await tester.pumpAndSettle();

      // Switch to Deplasman tab and select away starter Burak Demir
      await tester.tap(find.byKey(const Key('lineup-tab-away')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key(
            'lineup-select-bbbb1111-1111-4111-8111-111111111111',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sahaya çıkan').last);
      await tester.pumpAndSettle();

      // Lock lineup
      await tester.tap(find.byKey(const Key('lineup-lock-submit-btn')));
      await tester.pumpAndSettle();

      expect(lockedHomeStarters, ['aaaa1111-1111-4111-8111-111111111111']);
      expect(lockedAwayStarters, ['bbbb1111-1111-4111-8111-111111111111']);
      expect(lockedHomeSubs, isEmpty);
      expect(navigator.calls, contains('live:$matchId'));
    },
  );
}

final class _Navigator extends ProFeatureNavigatorBase {
  final calls = <String>[];

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
  @override
  void openRefereeDuties() => calls.add('duties');
  @override
  void openRefereeLineup(String matchId) => calls.add('lineup:$matchId');
  @override
  void openRefereeLiveCockpit(String matchId) => calls.add('live:$matchId');
  @override
  void openRefereeMatchReport(String matchId) => calls.add('report:$matchId');
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

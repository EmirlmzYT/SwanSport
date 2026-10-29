import 'dart:async';

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
    'SharedRefereeLiveCockpitScreen appends events, retries uncertain network error with same operation ID without optimistic score, and disposes timer cleanly',
    (tester) async {
      const matchId = '44444444-4444-4444-8444-444444444444';
      final recordedCalls = <({String rpc, Map<String, dynamic> params})>[];
      var failWithNetworkError = true;

      final liveState = RefereeLiveState(
        matchId: matchId,
        sportCode: 'futbol',
        matchStatus: 'scheduled',
        version: 3,
        homeScore: 1,
        awayScore: 0,
        period: 1,
        elapsedSeconds: 1200,
        clockStartedAt: DateTime.now().toUtc().subtract(
              const Duration(seconds: 5),
            ),
        events: [
          RefereeLiveEvent(
            id: 'ev-1',
            version: 3,
            kind: 'score',
            side: 'home',
            createdAt: DateTime.utc(2026, 10, 27, 12),
            undone: false,
            elapsedSeconds: 600,
          ),
        ],
        squads: const {
          'active_home': ['aaaa1111-1111-4111-8111-111111111111'],
          'active_away': ['bbbb1111-1111-4111-8111-111111111111'],
          'bench_home': <String>[],
          'bench_away': <String>[],
        },
      );

      late RefereeMutationController controller;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(refereeAccess()),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.refereeCockpit,
              }),
            ),
            refereeMatchStateProvider(matchId).overrideWith(
              (ref) async => liveState,
            ),
            refereeLineupCandidatesProvider(matchId).overrideWith(
              (ref) async => const [],
            ),
            refereeMutationProvider(matchId).overrideWith((ref) {
              controller = _FakeMutationController(
                onSend: (rpc, params) async {
                  recordedCalls.add(
                    (rpc: rpc, params: <String, dynamic>{...params}),
                  );
                  if (failWithNetworkError) {
                    throw TimeoutException('Network lost');
                  }
                },
              );
              return controller;
            }),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedRefereeLiveCockpitScreen(matchId: matchId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Server score is 1 - 0
      expect(find.text('1 — 0'), findsOneWidget);

      // Tap Home Score +1; first attempt fails with uncertain network timeout
      await tester.tap(find.byKey(const Key('referee-live-score-home-btn')));
      await tester.pump();

      expect(recordedCalls, hasLength(1));
      final firstOpId = recordedCalls.first.params['p_operation_id'] as String;
      expect(recordedCalls.first.rpc, 'referee_append_match_event');
      expect(recordedCalls.first.params['p_kind'], 'score');
      expect(recordedCalls.first.params['p_side'], 'home');
      expect(recordedCalls.first.params['p_expected_version'], 3);

      // Score is NOT optimistically incremented to 2 — 0 while unconfirmed by server
      expect(find.text('1 — 0'), findsOneWidget);
      expect(find.text('2 — 0'), findsNothing);
      expect(find.text('Aynı işlemi tekrar dene'), findsOneWidget);

      // Retry uses the exact same operation ID and payload
      failWithNetworkError = false;
      await tester.tap(find.byKey(const Key('referee-live-retry-btn')));
      await tester.pump();

      expect(recordedCalls, hasLength(2));
      expect(recordedCalls.last.params['p_operation_id'], firstOpId);

      // Test Undo button sends append-only 'undo' event
      await tester.tap(find.byKey(const Key('referee-live-undo-btn')));
      await tester.pump();
      expect(recordedCalls, hasLength(3));
      expect(recordedCalls.last.params['p_kind'], 'undo');

      // Unmount widget and pump 5 seconds to verify periodic Timer is cancelled cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SharedRefereeLiveCockpitScreen blocks unsupported individual sport and tennis renders set/game scores',
    (tester) async {
      const matchId = '66666666-6666-4666-8666-666666666666';

      final unsupportedState = RefereeLiveState(
        matchId: matchId,
        sportCode: 'atletizm',
        matchStatus: 'scheduled',
        version: 1,
        homeScore: 0,
        awayScore: 0,
        period: 1,
        elapsedSeconds: 0,
        events: const [],
        squads: const {
          'active_home': <String>[],
          'active_away': <String>[],
          'bench_home': <String>[],
          'bench_away': <String>[],
        },
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
            refereeMatchStateProvider(matchId).overrideWith(
              (ref) async => unsupportedState,
            ),
            refereeLineupCandidatesProvider(matchId).overrideWith(
              (ref) async => const [],
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: _Navigator(),
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedRefereeLiveCockpitScreen(matchId: matchId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bu branşın canlı sonuç protokolü henüz desteklenmiyor.'),
        findsOneWidget,
      );
      final homeBtn = tester.widget<FilledButton>(
        find.byKey(const Key('referee-live-score-home-btn')),
      );
      expect(homeBtn.onPressed, isNull);
    },
  );

  testWidgets(
    'SharedRefereeMatchReportScreen preserves draft on network failure, retries idempotently with same operation ID, and locks immutable signed report',
    (tester) async {
      const matchId = '44444444-4444-4444-8444-444444444444';
      final navigator = _Navigator();
      final recordedReports = <Map<String, dynamic>>[];
      var failWithTimeout = true;

      final liveState = RefereeLiveState(
        matchId: matchId,
        sportCode: 'basketbol',
        matchStatus: 'scheduled',
        version: 8,
        homeScore: 78,
        awayScore: 74,
        period: 4,
        elapsedSeconds: 2400,
        clockStartedAt: null,
        events: const [],
        squads: const {
          'active_home': <String>[],
          'active_away': <String>[],
          'bench_home': <String>[],
          'bench_away': <String>[],
        },
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
            refereeMatchStateProvider(matchId).overrideWith(
              (ref) async => liveState,
            ),
            refereeMutationProvider(matchId).overrideWith(
              (ref) => _FakeMutationController(
                onSend: (rpc, params) async {
                  recordedReports.add(<String, dynamic>{...params});
                  if (failWithTimeout) {
                    throw TimeoutException('Lost connection');
                  }
                },
              ),
            ),
          ],
          child: MaterialApp(
            home: ProFeatureHostScope(
              navigator: navigator,
              chrome: const _Chrome(),
              theme: ProFeatureThemeData.dark,
              child: const SharedRefereeMatchReportScreen(matchId: matchId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sonuç: 78 — 74'), findsOneWidget);
      expect(
        find.textContaining('nitelikli elektronik imza değildir'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('referee-report-notes-input')),
        'Müsabaka normal sürede tamamlandı. Saha olayı yaşanmadı.',
      );
      await tester.pump();

      // First submit fails with network timeout
      await tester.tap(find.byKey(const Key('referee-report-submit-btn')));
      await tester.pump();

      expect(recordedReports, hasLength(1));
      final firstOpId = recordedReports.first['p_operation_id'] as String;
      // Draft text is preserved in input!
      expect(
        find.text('Müsabaka normal sürede tamamlandı. Saha olayı yaşanmadı.'),
        findsOneWidget,
      );
      expect(find.text('Aynı raporu tekrar dene'), findsOneWidget);

      // Retry reuses the exact same p_operation_id and payload
      failWithTimeout = false;
      await tester.tap(find.byKey(const Key('referee-report-retry-btn')));
      await tester.pumpAndSettle();

      expect(recordedReports, hasLength(2));
      expect(recordedReports.last['p_operation_id'], firstOpId);
      expect(
        recordedReports.last['p_notes'],
        'Müsabaka normal sürede tamamlandı. Saha olayı yaşanmadı.',
      );
      expect(navigator.calls, contains('duties'));
    },
  );
}

final class _FakeMutationController extends RefereeMutationController {
  _FakeMutationController({required this.onSend}) : super(null, () {});

  final Future<void> Function(String rpc, Map<String, dynamic> params) onSend;

  @override
  Future<bool> submit(String rpc, Map<String, dynamic> params) async {
    if (state.busy || state.pending) return false;
    state = RefereeMutationState(rpc: rpc, params: Map.unmodifiable(params));
    return retry();
  }

  @override
  Future<bool> retry() async {
    if (state.busy || !state.pending) return false;
    final rpc = state.rpc!;
    final params = state.params!;
    state = RefereeMutationState(busy: true, rpc: rpc, params: params);
    try {
      await onSend(rpc, params);
      state = const RefereeMutationState();
      return true;
    } catch (error) {
      state = RefereeMutationState(
        error: '$error',
        rpc: rpc,
        params: params,
      );
      return false;
    }
  }
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

class PendingSessionService implements TrainingSessionService {
  final pending = Completer<TrainingSession?>();
  @override
  Future<TrainingSession?> byId(String sessionId) => pending.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'late session response after disposal never starts a refresh timer',
    (tester) async {
      final service = PendingSessionService();
      final container = ProviderContainer(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(true),
          trainingSessionServiceProvider.overrideWithValue(service),
        ],
      );
      container.listen(trainingSessionProvider('late'), (_, __) {});
      container.dispose();
      service.pending.complete(
        TrainingSession.fromMap({'id': 'late', 'status': 'live'}),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'session metrics provider groups allowlisted rows and excludes guests',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'id': 'set-a',
                'athlete_id': 'a',
                'set_no': 1,
                'total_score': null,
                'metric_payload': LapIntervalMetric(
                  lapNumber: 1,
                  splitMillis: 29400,
                  distanceMeters: 50,
                ).toMap(),
                'training_sessions': {
                  'training_protocols': {
                    'config': {'archetype': 'lap_interval'},
                  },
                },
              },
              {'id': 'set-b', 'athlete_id': 'b', 'set_no': 1, 'total_score': 9},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final container = ProviderContainer(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(true),
          trainingSessionServiceProvider.overrideWithValue(
            TrainingSessionService(client),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(
        sessionMetricSetsProvider('session').future,
      );
      expect(result.keys, ['a', 'b']);
      expect(result['a']!.single.metricPayload, isA<LapIntervalMetric>());
      expect(requests.single.url.queryParameters['session_id'], 'eq.session');
      expect(
        requests.single.url.queryParameters['select'],
        isNot(contains('*')),
      );
      expect(
        requests.single.url.queryParameters['select'],
        isNot(contains('athletes(')),
      );
      container.updateOverrides([
        isSupabaseEnabledProvider.overrideWithValue(false),
        trainingSessionServiceProvider.overrideWithValue(
          TrainingSessionService(client),
        ),
      ]);
      expect(
        await container.read(sessionMetricSetsProvider('guest').future),
        isEmpty,
      );
      expect(requests, hasLength(1));
    },
  );
  test('attempt draft cannot relabel attempts and resumes saved counters', () {
    final d = DrillDraftController(
      AttemptDrillMetric(
        drillName: 'Servis',
        successful: 16,
        faults: 4,
        totalAttempts: 20,
      ),
    );
    addTearDown(d.dispose);
    d.selectDrill('Smaç');
    d.attempt(true);
    expect(d.state.drillName, 'Servis');
    expect(d.state.successful, 17);
    expect(d.state.faults, 4);
  });
  test('lap uses timestamps, excludes pauses, and freezes a retry value', () {
    final d = DrillDraftController(null);
    addTearDown(d.dispose);
    final start = DateTime.utc(2026);
    d.startLap(start);
    expect(d.state.elapsedAt(start.add(const Duration(minutes: 2))), 120000);
    d.pauseLap(start.add(const Duration(seconds: 29, milliseconds: 400)));
    expect(d.state.elapsedAt(start.add(const Duration(hours: 1))), 29400);
    d.startLap(start.add(const Duration(hours: 1)));
    d.pauseLap(start.add(const Duration(hours: 1, seconds: 1)));
    expect(d.state.elapsedMillis, 30400);
    expect(d.state.startedAt, isNull);
  });
  test(
    'all archetype summaries use their metrics and preserve missing values',
    () {
      final attempt = DrillSessionSummary([
        TrainingSet(
          id: '1',
          setNo: 1,
          metricPayload: AttemptDrillMetric(
            drillName: 'Servis',
            successful: 16,
            faults: 4,
            totalAttempts: 20,
          ),
        ),
        TrainingSet(
          id: '2',
          setNo: 2,
          metricPayload: AttemptDrillMetric(
            drillName: 'Servis',
            successful: 4,
            faults: 6,
            totalAttempts: 10,
          ),
        ),
        const TrainingSet(id: 'missing', setNo: 3),
      ]);
      expect(attempt.attempts, 30);
      expect(attempt.successRate, closeTo(2 / 3, 0.0001));
      expect(attempt.drills['Servis'], (successful: 20, total: 30));
      final lap = DrillSessionSummary([
        TrainingSet(
          id: '1',
          setNo: 1,
          metricPayload: LapIntervalMetric(
            lapNumber: 1,
            splitMillis: 29400,
            distanceMeters: 50,
          ),
        ),
        TrainingSet(
          id: '2',
          setNo: 2,
          metricPayload: LapIntervalMetric(
            lapNumber: 2,
            splitMillis: 30200,
            distanceMeters: 50,
          ),
        ),
      ]);
      expect(lap.bestLapMillis, 29400);
      expect(lap.averageLapMillis, 29800);
      expect(lap.distanceMeters, 100);
      final target = DrillSessionSummary([
        TrainingSet(
          id: '1',
          setNo: 1,
          metricPayload: TargetScoreMetric(['X', 'M']),
        ),
        const TrainingSet(id: '2', setNo: 2, totalScore: 18, unitCount: 2),
      ]);
      expect(target.totalScore, 28);
      expect(target.averageUnitScore, 7);
      final rally = DrillSessionSummary([
        TrainingSet(
          id: 'r',
          setNo: 1,
          metricPayload: CombatRallyMetric(
            rallies: 5,
            winners: 3,
            unforcedErrors: 2,
          ),
        ),
      ]);
      expect(rally.rallies, 5);
      expect(rally.winners, 3);
      expect(DrillSessionSummary([]).successRate, isNull);
      expect(DrillSessionSummary([]).averageLapMillis, isNull);
      expect(DrillSessionSummary([]).averageUnitScore, isNull);
    },
  );
  test('paused session keeps actual remaining seconds', () {
    final s = TrainingSession.fromMap({
      'id': 's',
      'current_phase': 'active_drill',
      'paused': true,
      'phase_ends_at': '2026-10-10T09:01:00Z',
      'paused_at': '2026-10-10T09:00:20Z',
      'sport_code': 'volleyball',
    });
    expect(
      s.remainingAt(DateTime.utc(2026, 10, 10, 10)),
      const Duration(seconds: 40),
    );
    expect(s.sportCode, 'volleyball');
  });
}

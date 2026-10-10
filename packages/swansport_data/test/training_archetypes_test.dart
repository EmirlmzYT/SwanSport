import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

Map<String, Object?> config(String a) => {
  'archetype': a,
  'set_count': 2,
  'units_per_set': 20,
  'prep_seconds': 10,
  'shoot_seconds': 60,
  'rest_seconds': 15,
  'max_unit_score': 10,
  'entry_mode': 'flexible',
  'mode': 'technique',
  if (a == 'target_score') 'collect_seconds': 30,
};
final metrics = <DrillMetricPayload>[
  TargetScoreMetric(['X', 'M', '9']),
  AttemptDrillMetric(
    drillName: 'servis',
    successful: 16,
    faults: 4,
    totalAttempts: 20,
  ),
  LapIntervalMetric(
    lapNumber: 3,
    splitMillis: 29400,
    distanceMeters: 50,
    strokeRate: 34,
  ),
  CombatRallyMetric(rallies: 20, winners: 8, unforcedErrors: 4),
];

Map<String, Object?> requestBody(http.Request r) =>
    (jsonDecode(r.body) as Map).cast<String, Object?>();

void main() {
  test(
    'legacy model keeps missing vs zero and optional metric compatibility',
    () {
      expect(TrainingSet.fromMap({'id': 's', 'set_no': 1}).isMissing, true);
      expect(
        TrainingSet.fromMap({
          'id': 's',
          'set_no': 1,
          'total_score': 0,
        }).isMissing,
        false,
      );
      expect(
        TrainingSet.fromMap(
          {'id': 's', 'set_no': 1, 'metric_payload': <String, Object?>{}},
        ).metricPayload,
        null,
      );
      expect(
        TrainingProtocolConfig.fromMap(config('attempt_drill')).collectSeconds,
        0,
      );
      expect(
        TrainingProtocolConfig.fromMap(config('attempt_drill')).hasCollect,
        false,
      );
    },
  );
  for (final metric in metrics) {
    final a = metric.archetype.wireName;
    test(
      '$a service/provider reads metric and uses canonical protocol config',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.invalid',
          'test',
          httpClient: MockClient((r) async {
            requests.add(r);
            Object body = [];
            if (r.url.path.endsWith('/training_sessions')) {
              body = [
                {
                  'id': 'session',
                  'club_id': 'club',
                  'current_phase': a == 'lap_interval'
                      ? 'lap_active'
                      : 'active_drill',
                  'training_protocols': {'name': 'Drill', 'config': config(a)},
                },
              ];
            }
            if (r.url.path.endsWith('/training_sets')) {
              body = [
                {
                  'id': 'set',
                  'set_no': 1,
                  'total_score': null,
                  'unit_count': 1,
                  'metric_payload': metric.toMap(),
                  'training_sessions': {
                    'training_protocols': {'config': config(a)},
                  },
                },
              ];
            }
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        );
        addTearDown(client.dispose);
        final service = TrainingSessionService(client);
        final container = ProviderContainer(
          overrides: [
            isSupabaseEnabledProvider.overrideWithValue(true),
            trainingSessionServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        expect(
          (await container.read(
            sessionConfigProvider('session').future,
          ))!.archetype,
          metric.archetype,
        );
        final rows = await service.mySets('session', 'athlete');
        expect(rows.single.metricPayload!.toMap(), metric.toMap());
        expect(rows.single.isMissing, false);
        expect(
          requests.last.url.queryParameters['select'],
          contains('metric_payload'),
        );
        expect(
          requests.last.url.queryParameters['select'],
          contains('training_sessions(training_protocols(config))'),
        );
      },
    );
    test(
      '$a submit and audited correction send exact typed RPC parameters',
      () async {
        final requests = <http.Request>[];
        final client = SupabaseClient(
          'https://example.invalid',
          'test',
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              'null',
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final service = TrainingSessionService(client);
        await service.submitSet(
          sessionId: 'session',
          setNo: 1,
          metricPayload: metric,
        );
        expect(requests.single.url.path, '/rest/v1/rpc/submit_set_score');
        expect(jsonDecode(requests.single.body), {
          'p_session': 'session',
          'p_set_no': 1,
          'p_total': null,
          'p_entries': null,
          'p_metric_payload': metric.toMap(),
        });
        await service.correctLockedSet(
          setId: 'set',
          total: null,
          reason: 'Düzeltme',
          metricPayload: metric,
        );
        expect(requests.last.url.path, '/rest/v1/rpc/correct_locked_set');
        expect(requestBody(requests.last)['p_metric_payload'], metric.toMap());
      },
    );
  }
  test(
    'legacy submit, phase wire names and coach note existing event provider',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(
            r.url.path.endsWith('/training_session_events')
                ? jsonEncode([
                    {
                      'id': 'note',
                      'athlete_id': 'athlete',
                      'new_value': {'note': 'Dirsek yüksek', 'tag': 'servis'},
                      'created_at': '2026-10-10T12:00:00Z',
                    },
                  ])
                : 'null',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final service = TrainingSessionService(client);
      await service.submitSet(
        sessionId: 'session',
        setNo: 1,
        entries: [10, null, 9],
      );
      expect(
        requestBody(requests.last)['p_metric_payload'],
        <String, Object?>{},
      );
      for (final phase in [
        SessionPhase.activeDrill,
        SessionPhase.lapActive,
        SessionPhase.restInterval,
        SessionPhase.score,
      ]) {
        await service.advancePhase('session', phase: phase);
        expect(requestBody(requests.last)['p_phase'], phase.wireName);
      }
      await service.submitCoachDrillNote(
        'session',
        'athlete',
        'Dirsek yüksek',
        'servis',
      );
      expect(requests.last.url.path, '/rest/v1/rpc/submit_coach_drill_note');
      expect(jsonDecode(requests.last.body), {
        'p_session': 'session',
        'p_athlete': 'athlete',
        'p_note': 'Dirsek yüksek',
        'p_tag': 'servis',
      });
      final container = ProviderContainer(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(true),
          trainingSessionServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final notes = await container.read(
        sessionCoachDrillNotesProvider('session').future,
      );
      expect(notes.single.note, 'Dirsek yüksek');
      expect(notes.single.tag, 'servis');
      expect(requests.last.url.queryParameters['action'], 'eq.drill_note');
    },
  );
  test('disabled backend providers do not construct a service', () async {
    final container = ProviderContainer(
      overrides: [
        isSupabaseEnabledProvider.overrideWithValue(false),
        trainingSessionServiceProvider.overrideWith(
          (ref) => throw StateError('must not read'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(sessionConfigProvider('s').future), null);
    expect(
      await container.read(sessionCoachDrillNotesProvider('s').future),
      isEmpty,
    );
    expect(await container.read(mySessionSetsProvider('s').future), isEmpty);
  });
  test('malformed metrics and notes fail explicitly', () {
    expect(
      () => TrainingSet.fromMap(
        {'id': 's', 'set_no': 1, 'metric_payload': <Object?>[]},
      ),
      throwsFormatException,
    );
    expect(
      () => CoachDrillNote.fromMap({
        'id': 'n',
        'new_value': {'note': 3},
      }),
      throwsFormatException,
    );
  });
}

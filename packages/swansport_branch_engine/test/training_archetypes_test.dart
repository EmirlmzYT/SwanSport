import 'dart:convert';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> config(TrainingArchetype a, {int rest = 15}) => {
  'archetype': a.wireName,
  'set_count': 2,
  'units_per_set': 20,
  'prep_seconds': 10,
  'shoot_seconds': 60,
  'collect_seconds': 30,
  'rest_seconds': rest,
  'max_unit_score': 10,
  'entry_mode': 'flexible',
  'mode': 'technique',
};

void main() {
  final samples = <DrillMetricPayload>[
    TargetScoreMetric(['X', '10', '9', 'M']),
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
  for (final a in TrainingArchetype.values) {
    test('${a.name} config roundtrip and phase durations', () {
      final c = TrainingProtocolConfig.fromMap(config(a));
      c.validate();
      expect(c.archetype, a);
      expect(c.toMap(), config(a));
      expect(c.hasCollect, a == TrainingArchetype.targetScore);
      expect(c.plannedUnits, a == TrainingArchetype.lapInterval ? 2 : 40);
      expect(phaseSeconds(SessionPhase.activeDrill, c.toMap()), 60);
      expect(phaseSeconds(SessionPhase.lapActive, c.toMap()), 60);
      expect(phaseSeconds(SessionPhase.restInterval, c.toMap()), 15);
    });
    final metric = samples.firstWhere((m) => m.archetype == a);
    test('${a.name} typed JSON roundtrip and immutable copy', () {
      final raw = (jsonDecode(jsonEncode(metric.toMap())) as Map)
          .cast<String, Object?>();
      expect(DrillMetricPayload.fromMap(a, raw).toMap(), metric.toMap());
      expect(
        () => DrillMetricPayload.fromMap(a, {...raw, 'athlete_id': 'private'}),
        throwsFormatException,
      );
    });
    for (final key in metric.toMap().keys) {
      test('${a.name} validates $key types/missing/null', () {
        final raw = metric.toMap();
        final missing = {...raw}..remove(key);
        if (key != 'stroke_rate') {
          expect(
            () => DrillMetricPayload.fromMap(a, missing),
            throwsFormatException,
          );
        }
        for (final invalid in [
          null,
          true,
          <String, Object?>{},
          <Object?>[],
          double.nan,
        ]) {
          expect(
            () => DrillMetricPayload.fromMap(a, {...raw, key: invalid}),
            throwsFormatException,
          );
        }
      });
    }
    if (a == TrainingArchetype.targetScore) continue;
    test('${a.name} complete multi-set flow skips collect/score', () {
      final active = a == TrainingArchetype.lapInterval
          ? SessionPhase.lapActive
          : SessionPhase.activeDrill;
      final rest = a == TrainingArchetype.lapInterval
          ? SessionPhase.restInterval
          : SessionPhase.rest;
      final c = config(a);
      var step = const PhaseStep(SessionPhase.prep, 1);
      final actual = <PhaseStep>[];
      while (step.phase != SessionPhase.done) {
        step = nextPhase(step.phase, step.setNo, c);
        actual.add(step);
      }
      expect(actual, [
        PhaseStep(active, 1),
        PhaseStep(rest, 1),
        const PhaseStep(SessionPhase.prep, 2),
        PhaseStep(active, 2),
        const PhaseStep(SessionPhase.done, 2),
      ]);
      expect(
        nextPhase(active, 1, config(a, rest: 0)),
        const PhaseStep(SessionPhase.prep, 2),
      );
      expect(
        nextPhase(SessionPhase.done, 2, c),
        const PhaseStep(SessionPhase.done, 2),
      );
      expect(
        () => nextPhase(SessionPhase.collect, 1, c),
        throwsFormatException,
      );
      expect(active.acceptsScore, isTrue);
    });
  }
  test(
    'legacy config defaults target, malformed optional scalars parse safely',
    () {
      final raw = config(TrainingArchetype.targetScore)..remove('archetype');
      expect(
        TrainingProtocolConfig.fromMap(raw).archetype,
        TrainingArchetype.targetScore,
      );
      expect(
        nextPhase(SessionPhase.prep, 1, raw),
        const PhaseStep(SessionPhase.shoot, 1),
      );
      expect(
        nextPhase(SessionPhase.shoot, 1, raw),
        const PhaseStep(SessionPhase.collect, 1),
      );
      expect(
        TrainingProtocolConfig.fromMap(
          {'entry_mode': [], 'mode': true, 'set_count': double.infinity},
        ).setCount,
        1,
      );
      expect(() => TrainingArchetype.parse('other'), throwsFormatException);
      expect(SessionPhase.parse('active_drill'), SessionPhase.activeDrill);
      expect(SessionPhase.parse('lap_active'), SessionPhase.lapActive);
      expect(SessionPhase.parse('rest_interval'), SessionPhase.restInterval);
      expect(TrainingPhase.completed, SessionPhase.done);
    },
  );
  test('target marks preserve X/M and reject invalid values/mutable input', () {
    final marks = ['X', 'M', '10'];
    final m = TargetScoreMetric(marks);
    marks.add('9');
    expect(m.total, 20);
    expect(m.marks.length, 3);
    expect(() => m.marks.add('9'), throwsUnsupportedError);
    for (final bad in ['11', '-1', 'x', 'miss', '1.5']) {
      expect(() => TargetScoreMetric([bad]), throwsFormatException);
    }
    expect(() => TargetScoreMetric([]), throwsFormatException);
  });
  test(
    'attempt consistency, finite rates, bounds and all failures/successes',
    () {
      expect(
        AttemptDrillMetric(
          drillName: 'şut',
          successful: 0,
          faults: 20,
          totalAttempts: 20,
        ).successRate,
        0,
      );
      expect(
        AttemptDrillMetric(
          drillName: 'şut',
          successful: 20,
          faults: 0,
          totalAttempts: 20,
        ).successRate,
        1,
      );
      expect(
        () => AttemptDrillMetric(
          drillName: '',
          successful: 1,
          faults: 1,
          totalAttempts: 2,
        ),
        throwsFormatException,
      );
      expect(
        () => AttemptDrillMetric(
          drillName: 'a',
          successful: 16,
          faults: 3,
          totalAttempts: 20,
        ),
        throwsFormatException,
      );
      expect(
        () => AttemptDrillMetric(
          drillName: 'a',
          successful: 0,
          faults: 0,
          totalAttempts: 0,
        ),
        throwsFormatException,
      );
      final raw = samples[1].toMap();
      for (final rate in [0.9, double.infinity, double.nan]) {
        expect(
          () => DrillMetricPayload.fromMap(
            TrainingArchetype.attemptDrill,
            {...raw, 'success_rate': rate},
          ),
          throwsFormatException,
        );
      }
      for (final n in [-1, 1.5, '16', 1e20]) {
        expect(
          () => DrillMetricPayload.fromMap(
            TrainingArchetype.attemptDrill,
            {...raw, 'successful': n},
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('lap integer time, optional stroke and rally counter bounds', () {
    expect(
      LapIntervalMetric(
        lapNumber: 1,
        splitMillis: 1,
        distanceMeters: 1,
      ).toMap().containsKey('stroke_rate'),
      false,
    );
    expect(
      () => LapIntervalMetric(
        lapNumber: 0,
        splitMillis: 100,
        distanceMeters: 50,
      ),
      throwsFormatException,
    );
    expect(
      () => LapIntervalMetric(lapNumber: 1, splitMillis: 0, distanceMeters: 50),
      throwsFormatException,
    );
    expect(
      () => LapIntervalMetric(
        lapNumber: 1,
        splitMillis: 100,
        distanceMeters: 0,
      ),
      throwsFormatException,
    );
    expect(
      () => LapIntervalMetric(
        lapNumber: 1,
        splitMillis: 100,
        distanceMeters: 50,
        strokeRate: 301,
      ),
      throwsFormatException,
    );
    expect(
      () => CombatRallyMetric(rallies: 5, winners: 4, unforcedErrors: 2),
      throwsFormatException,
    );
    expect(
      () => CombatRallyMetric(rallies: 0, winners: 0, unforcedErrors: 0),
      throwsFormatException,
    );
  });
  test(
    'template validation rejects invalid timers, counts and nonfinite scores',
    () {
      for (final score in [double.nan, double.infinity]) {
        final c = TrainingProtocolConfig(
          setCount: 1,
          unitsPerSet: 1,
          prepSeconds: 0,
          shootSeconds: 5,
          restSeconds: 0,
          maxUnitScore: score,
          entryMode: ScoreEntryMode.simple,
          mode: TrainingMode.technique,
        );
        expect(c.validate, throwsFormatException);
      }
      for (final pair in <String, Object?>{
        'set_count': 0,
        'units_per_set': 101,
        'shoot_seconds': 4,
        'prep_seconds': -1,
        'rest_seconds': 3601,
        'collect_seconds': -1,
        'max_unit_score': 0,
      }.entries) {
        final raw = {
          ...config(TrainingArchetype.targetScore),
          pair.key: pair.value,
        };
        expect(
          () => TrainingProtocolConfig.fromMap(raw).validate(),
          throwsFormatException,
        );
      }
    },
  );
}

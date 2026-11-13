import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('all 60 branches complete measure result and progress contracts', () {
    expect(SportsCatalog.all, hasLength(60));
    final covered = <TrainingArchetype>{};

    for (final sport in SportsCatalog.all) {
      final profile = branchTrainingProfileFor(sport.code);
      final metric = _metric(profile);
      covered.add(profile.defaultArchetype);

      expect(metric.archetype, profile.defaultArchetype, reason: sport.code);
      expect(
        DrillMetricPayload.fromMap(metric.archetype, metric.toMap()).toMap(),
        metric.toMap(),
        reason: sport.code,
      );

      final config = _config(profile.defaultArchetype);
      var step = const PhaseStep(SessionPhase.prep, 1);
      var measured = false;
      for (var guard = 0;
          guard < 12 && step.phase != SessionPhase.done;
          guard++) {
        step = nextPhase(step.phase, step.setNo, config);
        measured = measured || step.phase.acceptsScore;
      }
      expect(measured, isTrue, reason: '${sport.code} ölçüm aşaması');
      expect(step.phase, SessionPhase.done, reason: '${sport.code} bitiş');

      final summary = DrillSessionSummary([
        TrainingSet(id: sport.code, setNo: 1, metricPayload: metric),
      ]);
      expect(summary.completedSets, 1, reason: '${sport.code} sonuç');

      final progress = TrainingProgressEntry(
        sessionId: sport.code,
        setNo: 1,
        sportCode: sport.code,
        sourceKind: 'club',
        clubId: 'club-a',
        clubName: 'Swan Kulüp',
        startedAt: DateTime.utc(2026, 11, 13),
        archetype: metric.archetype.wireName,
        workName: profile.presetDrills.first,
        comparisonKey:
            '${sport.code}:club:club-a:${metric.archetype.wireName}:${profile.presetDrills.first}',
        primaryValue: 1,
        unit: 'kabul',
      );
      expect(
        groupComparableTrainingProgress([progress])
            .values
            .single
            .single
            .sportCode,
        sport.code,
        reason: '${sport.code} gelişim',
      );
    }

    expect(covered, TrainingArchetype.values.toSet());
  });
}

Map<String, Object?> _config(TrainingArchetype archetype) => {
      'archetype': archetype.wireName,
      'set_count': 1,
      'units_per_set': 3,
      'prep_seconds': 5,
      'shoot_seconds': 30,
      'collect_seconds': archetype == TrainingArchetype.targetScore ? 10 : 0,
      'rest_seconds': 0,
      'max_unit_score': 10,
      'entry_mode': 'flexible',
      'mode': 'technique',
    };

DrillMetricPayload _metric(BranchTrainingProfile profile) =>
    switch (profile.defaultArchetype) {
      TrainingArchetype.targetScore => TargetScoreMetric(['X', '10', 'M']),
      TrainingArchetype.attemptDrill => AttemptDrillMetric(
          drillName: profile.presetDrills.first,
          successful: 8,
          faults: 2,
          totalAttempts: 10,
        ),
      TrainingArchetype.lapInterval => LapIntervalMetric(
          lapNumber: 1,
          splitMillis: 42000,
          distanceMeters: profile.defaultDistances.first,
        ),
      TrainingArchetype.combatRally =>
        CombatRallyMetric(rallies: 10, winners: 4, unforcedErrors: 2),
      TrainingArchetype.strengthSet => StrengthSetMetric(
          exerciseName: profile.presetDrills.first,
          weightKg: 50,
          reps: 5,
          rpe: 7,
        ),
      TrainingArchetype.routineJudge => RoutineJudgeMetric(
          routineName: profile.presetDrills.first,
          difficultyScore: 5,
          executionScore: 8,
          deductions: 1,
        ),
      TrainingArchetype.mindTactical => MindTacticalMetric(
          taskName: profile.presetDrills.first,
          solvedCount: 8,
          failedCount: 2,
          durationSeconds: 120,
        ),
    };

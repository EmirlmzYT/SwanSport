import 'dart:io';
import 'package:test/test.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';

void main() {
  test('all 60 catalog sports have immutable vocabulary and a supported default', () {
    var root = Directory.current;
    while (!File('${root.path}/AGENTS.md').existsSync()) {
      if (root.parent.path == root.path) fail('Repository root not found');
      root = root.parent;
    }
    final source = File('${root.path}/packages/swansport_data/lib/src/sports_catalog.dart').readAsStringSync();
    final codes = RegExp("code: '([^']+)'").allMatches(source).map((m) => m[1]!).toSet();
    expect(codes, hasLength(60));
    expect(branchTrainingProfiles.keys.toSet(), codes);
    for (final code in codes) {
      final profile = branchTrainingProfileFor(code);
      expect(profile.sportCode, code);
      expect(profile.supportedArchetypes, contains(profile.defaultArchetype));
      expect(profile.presetDrills.length, inInclusiveRange(4, 6));
      expect(profile.setLabel, isNotEmpty);
      expect(() => profile.presetDrills.add('mutation'), throwsUnsupportedError);
    }
    expect(branchTrainingProfileFor('football').sportCode, 'futbol');
    expect(() => branchTrainingProfileFor('unknown'), throwsFormatException);
  });

  final metrics = <DrillMetricPayload>[
    StrengthSetMetric(exerciseName: 'Koparma', weightKg: 82.5, reps: 3, rpe: 8),
    RoutineJudgeMetric(routineName: 'Seri', difficultyScore: 5.5, executionScore: 8.5, deductions: 1),
    MindTacticalMetric(taskName: 'Mat', solvedCount: 3, failedCount: 1, durationSeconds: 120),
  ];
  for (final metric in metrics) {
    test('${metric.archetype.wireName} strict round trip', () {
      final raw = metric.toMap();
      expect(DrillMetricPayload.fromMap(metric.archetype, raw).toMap(), raw);
      expect(() => DrillMetricPayload.fromMap(metric.archetype, {...raw, 'private_note': 'no'}), throwsFormatException);
      for (final key in raw.keys) {
        expect(() => DrillMetricPayload.fromMap(metric.archetype, {...raw, key: null}), throwsFormatException);
      }
    });
    test('${metric.archetype.wireName} generic phase transitions', () {
      final config = {'archetype': metric.archetype.wireName, 'set_count': 2, 'rest_seconds': 30};
      expect(nextPhase(SessionPhase.prep, 1, config).phase, SessionPhase.activeDrill);
      expect(nextPhase(SessionPhase.activeDrill, 1, config).phase, SessionPhase.rest);
      expect(nextPhase(SessionPhase.rest, 1, config).setNo, 2);
      expect(nextPhase(SessionPhase.activeDrill, 2, config).phase, SessionPhase.done);
      expect(nextPhase(SessionPhase.activeDrill, 1, {...config, 'rest_seconds': 0}).phase, SessionPhase.prep);
    });
  }
  test('half kg, reps, RPE and nonfinite boundaries', () {
    for (final weight in [-0.5, 0.25, 1000.5, double.nan, double.infinity]) {
      expect(() => StrengthSetMetric(exerciseName: 'X', weightKg: weight, reps: 1), throwsFormatException);
    }
    for (final reps in [0, 1001]) {
      expect(() => StrengthSetMetric(exerciseName: 'X', weightKg: 0, reps: reps), throwsFormatException);
    }
    for (final rpe in [0, 11]) {
      expect(() => StrengthSetMetric(exerciseName: 'X', weightKg: 1000, reps: 1000, rpe: rpe), throwsFormatException);
    }
    final raw = {'exercise_name': 'X', 'weight_kg': 0, 'reps': 1};
    expect((DrillMetricPayload.fromMap(TrainingArchetype.strengthSet, raw) as StrengthSetMetric).goodLift, isTrue);
  });
  test('routine accepts negative/maximum net and rejects forged totals', () {
    expect(RoutineJudgeMetric(routineName: 'X', difficultyScore: 0, executionScore: 0, deductions: 100).netScore, -100);
    expect(RoutineJudgeMetric(routineName: 'X', difficultyScore: 100, executionScore: 100, deductions: 0).netScore, 200);
    expect(() => DrillMetricPayload.fromMap(TrainingArchetype.routineJudge, {...metrics[1].toMap(), 'net_score': 14}), throwsFormatException);
  });
  test('mind zero attempts is zero accuracy, not NaN or success', () {
    final zero = MindTacticalMetric(taskName: 'X', solvedCount: 0, failedCount: 0, durationSeconds: 1);
    expect(zero.accuracyRate, 0);
    expect(() => DrillMetricPayload.fromMap(zero.archetype, {...zero.toMap(), 'accuracy_rate': 1}), throwsFormatException);
    expect(() => MindTacticalMetric(taskName: 'X', solvedCount: 10001, failedCount: 0, durationSeconds: 1), throwsFormatException);
    expect(() => MindTacticalMetric(taskName: 'X', solvedCount: 0, failedCount: 0, durationSeconds: 86401), throwsFormatException);
  });
}

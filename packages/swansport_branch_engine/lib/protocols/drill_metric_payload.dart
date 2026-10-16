/// Persisted names are shared with 0105; absence means legacy target scoring.
enum TrainingArchetype {
  targetScore('target_score'),
  attemptDrill('attempt_drill'),
  lapInterval('lap_interval'),
  combatRally('combat_rally'),
  strengthSet('strength_set'),
  routineJudge('routine_judge'),
  mindTactical('mind_tactical');

  const TrainingArchetype(this.wireName);
  final String wireName;

  String get label => switch (this) {
    targetScore => 'Hedef puanı', attemptDrill => 'Deneme / teknik',
    lapInterval => 'Tur / interval', combatRally => 'Raund / ralli',
    strengthSet => 'Kuvvet / kaldırış', routineJudge => 'Seri / jüri puanı',
    mindTactical => 'Zihinsel / taktik',
  };

  static TrainingArchetype parse(Object? raw) {
    if (raw == null) return targetScore;
    return values.firstWhere(
      (a) => a.wireName == raw,
      orElse: () => throw FormatException('Geçersiz antrenman arketipi', raw),
    );
  }
}

/// Validated, immutable set metrics. No identities or arbitrary JSON fields.
sealed class DrillMetricPayload {
  const DrillMetricPayload();
  TrainingArchetype get archetype;
  Map<String, Object?> toMap();

  factory DrillMetricPayload.fromMap(
    TrainingArchetype archetype,
    Map<String, Object?> raw,
  ) {
    final DrillMetricPayload value;
    switch (archetype) {
      case TrainingArchetype.targetScore:
        final marks = raw['marks'];
        if (marks is! List || marks.any((m) => m is! String)) {
          throw const FormatException('marks metin dizisi olmalı');
        }
        value = TargetScoreMetric(marks.cast<String>());
      case TrainingArchetype.attemptDrill:
        value = AttemptDrillMetric(
          drillName: _text(raw, 'drill_name'),
          successful: _integer(raw, 'successful'),
          faults: _integer(raw, 'faults'),
          totalAttempts: _integer(raw, 'total_attempts'),
        );
        final rate = raw['success_rate'];
        if (rate is! num ||
            !rate.isFinite ||
            (rate - (value as AttemptDrillMetric).successRate).abs() >
                0.000001) {
          throw const FormatException('success_rate sayaçlarla uyuşmuyor');
        }
      case TrainingArchetype.lapInterval:
        value = LapIntervalMetric(
          lapNumber: _integer(raw, 'lap_number'),
          splitMillis: _integer(raw, 'split_millis'),
          distanceMeters: _integer(raw, 'distance_meters'),
          strokeRate: raw.containsKey('stroke_rate')
              ? _integer(raw, 'stroke_rate')
              : null,
        );
      case TrainingArchetype.combatRally:
        value = CombatRallyMetric(
          rallies: _integer(raw, 'rallies'),
          winners: _integer(raw, 'winners'),
          unforcedErrors: _integer(raw, 'unforced_errors'),
        );
      case TrainingArchetype.strengthSet:
        final goodLift = raw.containsKey('good_lift') ? raw['good_lift'] : true;
        if (goodLift is! bool) throw const FormatException('good_lift boolean olmalı');
        value = StrengthSetMetric(
          exerciseName: _text(raw, 'exercise_name'),
          weightKg: _number(raw, 'weight_kg'),
          reps: _integer(raw, 'reps'),
          rpe: raw.containsKey('rpe') ? _integer(raw, 'rpe') : null,
          goodLift: goodLift,
        );
      case TrainingArchetype.routineJudge:
        value = RoutineJudgeMetric(
          routineName: _text(raw, 'routine_name'),
          difficultyScore: _number(raw, 'difficulty_score'),
          executionScore: _number(raw, 'execution_score'),
          deductions: _number(raw, 'deductions'),
        );
        final net = _number(raw, 'net_score');
        if (net < -100 || net > 200 || (net - (value as RoutineJudgeMetric).netScore).abs() > 0.000001) {
          throw const FormatException('net_score puanlarla uyuşmuyor');
        }
      case TrainingArchetype.mindTactical:
        value = MindTacticalMetric(
          taskName: _text(raw, 'task_name'),
          solvedCount: _integer(raw, 'solved_count'),
          failedCount: _integer(raw, 'failed_count'),
          durationSeconds: _integer(raw, 'duration_seconds'),
        );
        final accuracy = _number(raw, 'accuracy_rate');
        if (accuracy < 0 || accuracy > 1 || (accuracy - (value as MindTacticalMetric).accuracyRate).abs() > 0.000001) {
          throw const FormatException('accuracy_rate sayaçlarla uyuşmuyor');
        }
    }
    if (raw.keys.any((k) => !value.toMap().containsKey(k))) {
      throw const FormatException('Bilinmeyen metrik alanı');
    }
    return value;
  }
}

final class StrengthSetMetric extends DrillMetricPayload {
  StrengthSetMetric({required this.exerciseName, required this.weightKg,
    required this.reps, this.rpe, this.goodLift = true}) {
    _validateName(exerciseName);
    if (!weightKg.isFinite || weightKg < 0 || weightKg > 1000 ||
        (weightKg * 2) % 1 != 0 || reps < 1 || reps > 1000 ||
        (rpe != null && (rpe! < 1 || rpe! > 10))) {
      throw const FormatException('Kaldırış metriği geçersiz');
    }
  }
  final String exerciseName;
  final num weightKg;
  final int reps;
  final int? rpe;
  final bool goodLift;
  @override
  TrainingArchetype get archetype => TrainingArchetype.strengthSet;
  @override
  Map<String, Object?> toMap() => {
    'exercise_name': exerciseName, 'weight_kg': weightKg, 'reps': reps,
    if (rpe != null) 'rpe': rpe, 'good_lift': goodLift,
  };
}

final class RoutineJudgeMetric extends DrillMetricPayload {
  RoutineJudgeMetric({required this.routineName, required this.difficultyScore,
    required this.executionScore, required this.deductions}) {
    _validateName(routineName);
    for (final score in [difficultyScore, executionScore, deductions]) {
      if (!score.isFinite || score < 0 || score > 100) {
        throw const FormatException('Seri puanı geçersiz');
      }
    }
  }
  final String routineName;
  final num difficultyScore, executionScore, deductions;
  num get netScore => difficultyScore + executionScore - deductions;
  @override
  TrainingArchetype get archetype => TrainingArchetype.routineJudge;
  @override
  Map<String, Object?> toMap() => {
    'routine_name': routineName, 'difficulty_score': difficultyScore,
    'execution_score': executionScore, 'deductions': deductions, 'net_score': netScore,
  };
}

final class MindTacticalMetric extends DrillMetricPayload {
  MindTacticalMetric({required this.taskName, required this.solvedCount,
    required this.failedCount, required this.durationSeconds}) {
    _validateName(taskName);
    if (solvedCount < 0 || solvedCount > 10000 || failedCount < 0 ||
        failedCount > 10000 || durationSeconds < 1 || durationSeconds > 86400) {
      throw const FormatException('Zihinsel çalışma metriği geçersiz');
    }
  }
  final String taskName;
  final int solvedCount, failedCount, durationSeconds;
  double get accuracyRate => solvedCount + failedCount == 0
      ? 0 : solvedCount / (solvedCount + failedCount);
  @override
  TrainingArchetype get archetype => TrainingArchetype.mindTactical;
  @override
  Map<String, Object?> toMap() => {
    'task_name': taskName, 'solved_count': solvedCount, 'failed_count': failedCount,
    'duration_seconds': durationSeconds, 'accuracy_rate': accuracyRate,
  };
}

void _validateName(String value) {
  if (value.trim().isEmpty || value.trim().length > 120) {
    throw const FormatException('Ad 1–120 karakter olmalı');
  }
}

num _number(Map<String, Object?> raw, String key) {
  final value = raw[key];
  if (value is! num || !value.isFinite) throw FormatException('$key sonlu sayı olmalı');
  return value;
}

final class AttemptDrillMetric extends DrillMetricPayload {
  AttemptDrillMetric({
    required this.drillName,
    required this.successful,
    required this.faults,
    required this.totalAttempts,
  }) {
    if (drillName.trim().isEmpty ||
        drillName.length > 120 ||
        successful < 0 ||
        faults < 0 ||
        totalAttempts < 1 ||
        totalAttempts > 10000 ||
        successful > totalAttempts ||
        faults > totalAttempts ||
        successful + faults != totalAttempts) {
      throw const FormatException('Deneme/başarı/hata sayaçları geçersiz');
    }
  }
  final String drillName;
  final int successful, faults, totalAttempts;
  double get successRate => successful / totalAttempts;
  @override
  TrainingArchetype get archetype => TrainingArchetype.attemptDrill;
  @override
  Map<String, Object?> toMap() => {
    'drill_name': drillName,
    'successful': successful,
    'faults': faults,
    'total_attempts': totalAttempts,
    'success_rate': successRate,
  };
}

final class LapIntervalMetric extends DrillMetricPayload {
  LapIntervalMetric({
    required this.lapNumber,
    required this.splitMillis,
    required this.distanceMeters,
    this.strokeRate,
  }) {
    if (lapNumber < 1 ||
        lapNumber > 100 ||
        splitMillis < 1 ||
        splitMillis > 86400000 ||
        distanceMeters < 1 ||
        distanceMeters > 100000 ||
        (strokeRate != null && (strokeRate! < 0 || strokeRate! > 300))) {
      throw const FormatException('Tur derecesi/mesafe geçersiz');
    }
  }
  final int lapNumber, splitMillis, distanceMeters;
  final int? strokeRate;
  @override
  TrainingArchetype get archetype => TrainingArchetype.lapInterval;
  @override
  Map<String, Object?> toMap() => {
    'lap_number': lapNumber,
    'split_millis': splitMillis,
    'distance_meters': distanceMeters,
    if (strokeRate != null) 'stroke_rate': strokeRate,
  };
}

final class CombatRallyMetric extends DrillMetricPayload {
  CombatRallyMetric({
    required this.rallies,
    required this.winners,
    required this.unforcedErrors,
  }) {
    if (rallies < 1 ||
        rallies > 10000 ||
        winners < 0 ||
        unforcedErrors < 0 ||
        winners > rallies ||
        unforcedErrors > rallies ||
        winners + unforcedErrors > rallies) {
      throw const FormatException('Ralli sayaçları geçersiz');
    }
  }
  final int rallies, winners, unforcedErrors;
  @override
  TrainingArchetype get archetype => TrainingArchetype.combatRally;
  @override
  Map<String, Object?> toMap() => {
    'rallies': rallies,
    'winners': winners,
    'unforced_errors': unforcedErrors,
  };
}

final class TargetScoreMetric extends DrillMetricPayload {
  TargetScoreMetric(List<String> marks) : marks = List.unmodifiable(marks) {
    if (marks.isEmpty ||
        marks.length > 100 ||
        marks.any(
          (m) => !const {
            'X',
            'M',
            '0',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
          }.contains(m),
        )) {
      throw const FormatException('Hedef puanları geçersiz');
    }
  }
  final List<String> marks;
  int get total => marks.fold(
    0,
    (sum, m) =>
        sum +
        (m == 'X'
            ? 10
            : m == 'M'
            ? 0
            : int.parse(m)),
  );
  @override
  TrainingArchetype get archetype => TrainingArchetype.targetScore;
  @override
  Map<String, Object?> toMap() => {'marks': marks};
}

int _integer(Map<String, Object?> raw, String key) {
  final n = raw[key];
  if (n is! num ||
      !n.isFinite ||
      n != n.truncateToDouble() ||
      n.abs() > 9007199254740991) {
    throw FormatException('$key tamsayı olmalı');
  }
  return n.toInt();
}

String _text(Map<String, Object?> raw, String key) {
  final s = raw[key];
  if (s is! String) throw FormatException('$key metin olmalı');
  return s;
}

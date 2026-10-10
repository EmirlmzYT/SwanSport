/// Persisted names are shared with 0105; absence means legacy target scoring.
enum TrainingArchetype {
  targetScore('target_score'),
  attemptDrill('attempt_drill'),
  lapInterval('lap_interval'),
  combatRally('combat_rally');

  const TrainingArchetype(this.wireName);
  final String wireName;

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
    }
    if (raw.keys.any((k) => !value.toMap().containsKey(k))) {
      throw const FormatException('Bilinmeyen metrik alanı');
    }
    return value;
  }
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

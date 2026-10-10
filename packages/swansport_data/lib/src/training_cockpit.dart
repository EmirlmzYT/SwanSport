import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';

import 'club_data.dart';
import 'training_session_service.dart';

/// Drafts survive refreshes of the server session; a new set gets a new key.
typedef DrillDraftKey = ({String sessionId, int setNo});

final drillDraftProvider =
    StateNotifierProvider.family<
      DrillDraftController,
      DrillDraft,
      DrillDraftKey
    >((ref, key) {
      ref.watch(
        currentProfileProvider.select((profile) => profile.valueOrNull?.id),
      );
      final sets =
          ref.read(mySessionSetsProvider(key.sessionId)).valueOrNull ?? [];
      final existing = sets.where((s) => s.setNo == key.setNo);
      return DrillDraftController(
        existing.isEmpty ? null : existing.first.metricPayload,
      );
    });

class DrillDraft {
  const DrillDraft({
    this.drillName = '',
    this.successful = 0,
    this.faults = 0,
    this.rallies = 0,
    this.winners = 0,
    this.errors = 0,
    this.marks = const [],
    this.elapsedMillis = 0,
    this.startedAt,
  });
  final String drillName;
  final int successful, faults, rallies, winners, errors, elapsedMillis;
  final List<String> marks;
  final DateTime? startedAt;
  int elapsedAt(DateTime now) =>
      elapsedMillis +
      (startedAt == null
          ? 0
          : now.difference(startedAt!).inMilliseconds.clamp(0, 86400000));
}

class DrillDraftController extends StateNotifier<DrillDraft> {
  DrillDraftController(DrillMetricPayload? metric)
    : super(
        switch (metric) {
          final AttemptDrillMetric m => DrillDraft(
            drillName: m.drillName,
            successful: m.successful,
            faults: m.faults,
          ),
          final CombatRallyMetric m => DrillDraft(
            rallies: m.rallies,
            winners: m.winners,
            errors: m.unforcedErrors,
          ),
          final TargetScoreMetric m => DrillDraft(marks: m.marks),
          final LapIntervalMetric m => DrillDraft(elapsedMillis: m.splitMillis),
          _ => const DrillDraft(),
        },
      );

  void _change({
    String? drill,
    int? successful,
    int? faults,
    int? rallies,
    int? winners,
    int? errors,
    List<String>? marks,
    int? elapsed,
    DateTime? start,
    bool clock = false,
  }) {
    state = DrillDraft(
      drillName: drill ?? state.drillName,
      successful: successful ?? state.successful,
      faults: faults ?? state.faults,
      rallies: rallies ?? state.rallies,
      winners: winners ?? state.winners,
      errors: errors ?? state.errors,
      marks: marks == null ? state.marks : List.unmodifiable(marks),
      elapsedMillis: elapsed ?? state.elapsedMillis,
      startedAt: clock ? start : state.startedAt,
    );
  }

  // A set has one drill. Switching after recording would relabel its attempts.
  void selectDrill(String name) {
    if (state.successful + state.faults == 0) _change(drill: name);
  }

  void attempt(bool success) {
    if (state.successful + state.faults >= 10000) return;
    _change(
      successful: state.successful + (success ? 1 : 0),
      faults: state.faults + (success ? 0 : 1),
    );
  }

  void rally({required bool winner}) {
    if (state.rallies >= 10000) return;
    _change(
      rallies: state.rallies + 1,
      winners: state.winners + (winner ? 1 : 0),
      errors: state.errors + (winner ? 0 : 1),
    );
  }

  void mark(String value, int limit) {
    if (state.marks.length < limit) _change(marks: [...state.marks, value]);
  }

  void undoMark() {
    if (state.marks.isNotEmpty) {
      _change(marks: state.marks.sublist(0, state.marks.length - 1));
    }
  }

  void startLap(DateTime now) {
    if (state.startedAt == null) _change(start: now, clock: true);
  }

  void pauseLap(DateTime now) =>
      _change(elapsed: state.elapsedAt(now), clock: true);
}

class DrillSessionSummary {
  DrillSessionSummary(Iterable<TrainingSet> sets) {
    for (final set in sets) {
      if (set.isMissing) continue;
      completedSets++;
      switch (set.metricPayload) {
        case final AttemptDrillMetric m:
          attempts += m.totalAttempts;
          successes += m.successful;
          final old = drills[m.drillName] ?? (successful: 0, total: 0);
          drills[m.drillName] = (
            successful: old.successful + m.successful,
            total: old.total + m.totalAttempts,
          );
        case final LapIntervalMetric m:
          lapMillis.add(m.splitMillis);
          distanceMeters += m.distanceMeters;
        case final CombatRallyMetric m:
          rallies += m.rallies;
          winners += m.winners;
          errors += m.unforcedErrors;
        case final TargetScoreMetric m:
          totalScore += m.total;
          recordedUnits += m.marks.length;
        case null:
          totalScore += set.totalScore ?? 0;
          recordedUnits += set.unitCount ?? set.entries.whereType<num>().length;
      }
    }
  }
  int attempts = 0, successes = 0, distanceMeters = 0, recordedUnits = 0;
  int completedSets = 0;
  int rallies = 0, winners = 0, errors = 0;
  num totalScore = 0;
  final List<int> lapMillis = [];
  final Map<String, ({int successful, int total})> drills = {};
  double? get successRate => attempts == 0 ? null : successes / attempts;
  int? get bestLapMillis =>
      lapMillis.isEmpty ? null : lapMillis.reduce((a, b) => a < b ? a : b);
  double? get averageLapMillis => lapMillis.isEmpty
      ? null
      : lapMillis.reduce((a, b) => a + b) / lapMillis.length;
  double? get averageUnitScore =>
      recordedUnits == 0 ? null : totalScore / recordedUnits;
}

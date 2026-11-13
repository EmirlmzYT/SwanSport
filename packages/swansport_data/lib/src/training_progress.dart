import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

typedef TrainingProgressRequest = ({
  String athleteId,
  DateTime from,
  DateTime to,
});

class TrainingProgressEntry {
  const TrainingProgressEntry({
    required this.sessionId,
    required this.setNo,
    required this.sportCode,
    required this.sourceKind,
    required this.startedAt,
    required this.archetype,
    required this.workName,
    required this.comparisonKey,
    required this.primaryValue,
    required this.unit,
    this.clubId,
    this.clubName,
    this.sharedFeedback,
  });

  factory TrainingProgressEntry.fromMap(Map<String, dynamic> map) =>
      TrainingProgressEntry(
        sessionId: map['session_id'] as String,
        setNo: (map['set_no'] as num).toInt(),
        sportCode: map['sport_code'] as String,
        sourceKind: map['source_kind'] as String,
        clubId: map['club_id'] as String?,
        clubName: map['club_name'] as String?,
        startedAt: DateTime.parse(map['started_at'] as String),
        archetype: map['archetype'] as String,
        workName: map['work_name'] as String,
        comparisonKey: map['comparison_key'] as String,
        primaryValue: map['primary_value'] as num,
        unit: map['unit'] as String,
        sharedFeedback: map['shared_feedback'] as String?,
      );

  final String sessionId;
  final int setNo;
  final String sportCode;
  final String sourceKind;
  final String? clubId;
  final String? clubName;
  final DateTime startedAt;
  final String archetype;
  final String workName;
  final String comparisonKey;
  final num primaryValue;
  final String unit;
  final String? sharedFeedback;

  bool get isPersonal => sourceKind == 'personal';
  bool get lowerIsBetter => archetype == 'lap_interval';
}

Map<String, List<TrainingProgressEntry>> groupComparableTrainingProgress(
  Iterable<TrainingProgressEntry> entries,
) {
  final groups = <String, List<TrainingProgressEntry>>{};
  for (final entry in entries) {
    (groups[entry.comparisonKey] ??= []).add(entry);
  }
  for (final group in groups.values) {
    group.sort((a, b) => a.startedAt.compareTo(b.startedAt));
  }
  return groups;
}

class TrainingProgressService {
  const TrainingProgressService(this._client);
  final SupabaseClient _client;

  Future<List<TrainingProgressEntry>> load(
    TrainingProgressRequest request,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'training_progress',
      params: {
        'p_athlete': request.athleteId,
        'p_from': _date(request.from),
        'p_to': _date(request.to),
      },
    );
    return [
      for (final row in rows)
        TrainingProgressEntry.fromMap((row as Map).cast<String, dynamic>()),
    ];
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final trainingProgressServiceProvider =
    Provider<TrainingProgressService>((ref) {
  return TrainingProgressService(ref.watch(supabaseClientProvider));
});

final trainingProgressProvider = FutureProvider.autoDispose
    .family<List<TrainingProgressEntry>, TrainingProgressRequest>(
  (ref, request) async {
    if (!ref.watch(isSupabaseEnabledProvider)) return const [];
    return ref.watch(trainingProgressServiceProvider).load(request);
  },
);

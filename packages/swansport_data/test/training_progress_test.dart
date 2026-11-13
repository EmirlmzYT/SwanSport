import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

TrainingProgressEntry entry({
  required String key,
  required String sport,
  required String source,
  required DateTime at,
  String? clubId,
}) =>
    TrainingProgressEntry(
      sessionId: '$key-${at.millisecondsSinceEpoch}',
      setNo: 1,
      sportCode: sport,
      sourceKind: source,
      clubId: clubId,
      clubName: clubId,
      startedAt: at,
      archetype: 'lap_interval',
      workName: '50 m',
      comparisonKey: key,
      primaryValue: 42000,
      unit: 'ms',
    );

void main() {
  test('only identical comparison keys form a progress group', () {
    final groups = groupComparableTrainingProgress([
      entry(
        key: 'yuzme:personal:personal:lap_interval:50',
        sport: 'yuzme',
        source: 'personal',
        at: DateTime.utc(2026, 11, 13),
      ),
      entry(
        key: 'yuzme:club:club-a:lap_interval:50',
        sport: 'yuzme',
        source: 'club',
        clubId: 'club-a',
        at: DateTime.utc(2026, 11, 12),
      ),
      entry(
        key: 'yuzme:club:club-a:lap_interval:100',
        sport: 'yuzme',
        source: 'club',
        clubId: 'club-a',
        at: DateTime.utc(2026, 11, 11),
      ),
      entry(
        key: 'tenis:club:club-a:combat_rally:score',
        sport: 'tenis',
        source: 'club',
        clubId: 'club-a',
        at: DateTime.utc(2026, 11, 10),
      ),
    ]);

    expect(groups, hasLength(4));
  });

  test('comparable entries are ordered chronologically', () {
    const key = 'yuzme:club:club-a:lap_interval:50';
    final groups = groupComparableTrainingProgress([
      entry(
        key: key,
        sport: 'yuzme',
        source: 'club',
        clubId: 'club-a',
        at: DateTime.utc(2026, 11, 13),
      ),
      entry(
        key: key,
        sport: 'yuzme',
        source: 'club',
        clubId: 'club-a',
        at: DateTime.utc(2026, 11, 12),
      ),
    ]);

    expect(groups[key]!.first.startedAt, DateTime.utc(2026, 11, 12));
  });
}

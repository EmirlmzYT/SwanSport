import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';

void main() {
  test('pilot branches expose realistic primary measurements', () {
    final archery = branchTrainingProfileFor('geleneksel-okculuk');
    final tennis = branchTrainingProfileFor('tenis');
    final swimming = branchTrainingProfileFor('yuzme');

    expect(archery.defaultArchetype, TrainingArchetype.targetScore);
    expect(archery.presetDrills, containsAll(['Çekiş', 'Salış', 'Hedef serisi']));
    expect(TargetScoreMetric(['X', '10', 'M']).total, 20);

    expect(tennis.defaultArchetype, TrainingArchetype.combatRally);
    expect(tennis.presetDrills, containsAll(['Servis', 'Forehand', 'Ralli']));
    expect(
      CombatRallyMetric(rallies: 12, winners: 5, unforcedErrors: 3).toMap(),
      {'rallies': 12, 'winners': 5, 'unforced_errors': 3},
    );

    expect(swimming.defaultArchetype, TrainingArchetype.lapInterval);
    expect(swimming.defaultDistances, [25, 50, 100, 200, 400]);
    expect(
      LapIntervalMetric(
        lapNumber: 1,
        splitMillis: 42750,
        distanceMeters: 50,
        strokeRate: 34,
      ).toMap(),
      {
        'lap_number': 1,
        'split_millis': 42750,
        'distance_meters': 50,
        'stroke_rate': 34,
      },
    );
  });
}

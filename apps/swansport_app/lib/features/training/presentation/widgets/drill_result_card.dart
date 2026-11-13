import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import 'branch_drill_pad.dart';

class DrillResultCard extends StatelessWidget {
  const DrillResultCard({
    required this.archetype,
    required this.sets,
    this.sportName,
    this.workName,
    this.performedAt,
    this.sourceLabel,
    super.key,
  });
  final TrainingArchetype archetype;
  final List<TrainingSet> sets;
  final String? sportName;
  final String? workName;
  final DateTime? performedAt;
  final String? sourceLabel;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final s = DrillSessionSummary(sets);
    final lines = switch (archetype) {
      TrainingArchetype.attemptDrill => [
          'Toplam deneme: ${s.attempts}',
          'Başarı: ${s.successRate == null ? '—' : '%${(100 * s.successRate!).round()}'}',
          for (final e in s.drills.entries)
            '${e.key}: ${e.value.successful}/${e.value.total}',
        ],
      TrainingArchetype.lapInterval => [
          'En iyi tur: ${s.bestLapMillis == null ? '—' : formatLapTime(s.bestLapMillis!)}',
          'Ortalama tur: ${s.averageLapMillis == null ? '—' : formatLapTime(s.averageLapMillis!)}',
          'Toplam mesafe: ${s.distanceMeters} m',
          for (final set in sets)
            if (set.metricPayload case final LapIntervalMetric m)
              'Tur ${m.lapNumber}: ${formatLapTime(m.splitMillis)} · ${m.distanceMeters} m',
        ],
      TrainingArchetype.combatRally => [
          'Toplam ralli: ${s.rallies}',
          'Winner: ${s.winners}',
          'Basit hata: ${s.errors}',
        ],
      TrainingArchetype.targetScore => [
          'Toplam puan: ${s.totalScore}',
          'Ortalama ok puanı: ${s.averageUnitScore?.toStringAsFixed(2) ?? '—'}',
        ],
      TrainingArchetype.strengthSet => [
          for (final set in sets)
            if (set.metricPayload case final StrengthSetMetric m)
              '${m.exerciseName}: ${m.weightKg} kg × ${m.reps} · ${m.goodLift ? 'Geçerli' : 'Geçersiz'}${m.rpe == null ? '' : ' · RPE ${m.rpe}'}'
        ],
      TrainingArchetype.routineJudge => [
          for (final set in sets)
            if (set.metricPayload case final RoutineJudgeMetric m)
              '${m.routineName}: ${m.netScore} (D ${m.difficultyScore} + E ${m.executionScore} − ${m.deductions})'
        ],
      TrainingArchetype.mindTactical => [
          for (final set in sets)
            if (set.metricPayload case final MindTacticalMetric m)
              '${m.taskName}: ${m.solvedCount} çözüm · ${m.failedCount} hata · %${(100 * m.accuracyRate).round()} · ${m.durationSeconds} sn'
        ],
    };
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Antrenman karnesi', style: SwanType.h3(c.ink)),
          if (sportName != null && sourceLabel != null) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(
              '$sportName · $sourceLabel',
              style: SwanType.bodySm(c.ink, w: FontWeight.w700),
            ),
          ],
          if (workName != null && performedAt != null)
            Text(
              '$workName · ${_date(performedAt!)}',
              style: SwanType.caption(c.inkMuted),
            ),
          const SizedBox(height: SwanSpace.md),
          if (s.completedSets == 0)
            Text(
              'Henüz sonuç kaydedilmedi.',
              style: SwanType.bodySm(c.inkMuted),
            ),
          for (final line in s.completedSets == 0 ? <String>[] : lines)
            Padding(
              padding: const EdgeInsets.only(bottom: SwanSpace.sm),
              child: Text(line, style: SwanType.body(c.ink)),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';
}

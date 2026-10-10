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
    super.key,
  });
  final TrainingArchetype archetype;
  final List<TrainingSet> sets;
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
}

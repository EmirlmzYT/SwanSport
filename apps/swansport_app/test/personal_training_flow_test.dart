import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/training/presentation/my_training_screen.dart';
import 'package:swansport_app/features/training/presentation/widgets/drill_result_card.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('personal training uses start and resume action hierarchy',
      (tester) async {
    const live = TrainingSession(
      id: 'session-1',
      clubId: '',
      kind: 'personal',
      status: 'live',
      phase: SessionPhase.activeDrill,
      currentSet: 1,
      setCount: 3,
      rhythm: SessionRhythm.individual,
      protocolName: 'Yüzme tempo',
      sportCode: 'yuzme',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLiveSessionProvider.overrideWith((ref) async => live),
          myTrainingHistoryProvider.overrideWith((ref) async => const []),
          sportContextOptionsProvider.overrideWithValue(
            AsyncData(catalogSportsFor(['yuzme'])),
          ),
          selectedSportContextProvider.overrideWith((ref) => 'yuzme'),
        ],
        child: const MaterialApp(home: MyTrainingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Devam et'), findsOneWidget);
    expect(find.text('Antrenman başlat'), findsOneWidget);
  });

  testWidgets('personal result card identifies branch work date and source',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DrillResultCard(
            archetype: TrainingArchetype.lapInterval,
            sets: const [],
            sportName: 'Yüzme',
            workName: '50 m Serbest',
            performedAt: DateTime(2026, 11, 12),
            sourceLabel: 'Bireysel',
          ),
        ),
      ),
    );

    expect(find.text('Yüzme · Bireysel'), findsOneWidget);
    expect(find.text('50 m Serbest · 12.11.2026'), findsOneWidget);
  });
}

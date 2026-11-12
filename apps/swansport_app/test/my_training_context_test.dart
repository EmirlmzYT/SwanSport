import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/training/presentation/my_training_screen.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:swansport_data/swansport_data.dart';

TrainingProtocol _swimmingProtocol() => TrainingProtocol(
      id: 'platform-swimming',
      name: 'Yüzme · Temel Teknik',
      sportCode: 'yuzme',
      version: 1,
      published: true,
      config: const TrainingProtocolConfig(
        setCount: 3,
        unitsPerSet: 1,
        prepSeconds: 10,
        shootSeconds: 120,
        collectSeconds: 0,
        restSeconds: 30,
        maxUnitScore: 10,
        entryMode: ScoreEntryMode.flexible,
        mode: TrainingMode.technique,
        archetype: TrainingArchetype.lapInterval,
      ),
    );

void main() {
  Future<void> render(
    WidgetTester tester, {
    List<TrainingHistoryEntry> history = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLiveSessionProvider.overrideWith((ref) async => null),
          myTrainingHistoryProvider.overrideWith((ref) async => history),
          sportContextOptionsProvider.overrideWithValue(
            AsyncData(catalogSportsFor(['yuzme', 'tenis'])),
          ),
          selectedSportContextProvider.overrideWith((ref) => 'yuzme'),
          trainingProtocolsProvider.overrideWith((ref) async => const []),
          personalTrainingProtocolsProvider('yuzme').overrideWith(
            (ref) async => [_swimmingProtocol()],
          ),
        ],
        child: const MaterialApp(home: MyTrainingScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bireysel başlangıç aktif kulüp yerine platform şablonunu açar',
      (tester) async {
    await render(tester);

    await tester.tap(find.text('Antrenman başlat'));
    await tester.pumpAndSettle();

    expect(find.text('Yüzme · Temel Teknik'), findsOneWidget);
    expect(find.text('Yüzme · Bireysel'), findsOneWidget);
    expect(find.textContaining('yalnızca senin geçmişinde'), findsOneWidget);
  });

  testWidgets('aynı branştaki geçmiş kulüp ve kaynakla ayırt edilir',
      (tester) async {
    await render(
      tester,
      history: [
        TrainingHistoryEntry.fromMap({
          'session_id': 'session-1',
          'kind': 'club',
          'protocol_name': 'Servis',
          'sport_code': 'yuzme',
          'club_id': 'club-1',
          'club_name': 'Lmz Spor Kulübü',
          'coach_name': 'Ayşe Antrenör',
          'started_at': '2026-11-12T09:00:00Z',
          'status': 'completed',
          'sets_done': 3,
          'set_count': 3,
        }),
      ],
    );

    expect(find.textContaining('Antrenörlü'), findsOneWidget);
    expect(find.textContaining('Lmz Spor Kulübü'), findsOneWidget);
    expect(find.textContaining('Ayşe Antrenör'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/training/presentation/my_training_screen.dart';
import 'package:swansport_app/features/training/presentation/session_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('SwanSport training wrapper opens the shared training list',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.sportTrainingSessions,
            }),
          ),
          myLiveSessionProvider.overrideWith((ref) async => null),
          myTrainingHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: MyTrainingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SharedTrainingListScreen), findsOneWidget);
    expect(find.text('Henüz antrenman kaydı yok.'), findsOneWidget);
  });

  testWidgets('legacy session route forwards a typed session id',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.sportTrainingSessions,
            }),
          ),
          trainingSessionProvider('session-1').overrideWith(
            (ref) async => const TrainingSession(
              id: 'session-1',
              clubId: 'club-1',
              kind: 'personal',
              status: 'live',
              phase: SessionPhase.shoot,
              currentSet: 1,
              setCount: 3,
              rhythm: SessionRhythm.shared,
              protocolName: 'Bireysel',
            ),
          ),
        ],
        child: MaterialApp(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const TrainingSessionScreen(),
          ),
          initialRoute: '/antrenman-oturumu',
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(
      '/antrenman-oturumu',
      arguments: const {'id': 'session-1'},
    );
    await tester.pumpAndSettle();
    expect(find.byType(SharedTrainingSessionScreen), findsOneWidget);
    expect(find.text('Bireysel'), findsOneWidget);
  });
}

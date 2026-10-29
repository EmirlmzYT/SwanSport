import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/training/presentation/my_training_screen.dart';
import 'package:swansport_app/features/training/presentation/session_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('SwanSport keeps its full training history experience',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLiveSessionProvider.overrideWith((ref) async => null),
          myTrainingHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: MyTrainingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Antrenmanlarım'), findsOneWidget);
    expect(find.text('Geçmiş'), findsOneWidget);
    expect(find.textContaining('henüz antrenman kaydın yok'), findsOneWidget);
  });

  testWidgets('SwanSport keeps the no-live-session guidance', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myLiveSessionProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: TrainingSessionScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aktif oturum yok'), findsOneWidget);
    expect(find.textContaining('Antrenman şablonlarından'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/training/presentation/protocol_list_screen.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('coach selects only the branch team before starting',
      (tester) async {
    final protocol = TrainingProtocol(
      id: 'protocol-tennis',
      name: 'Servis ve ralli',
      sportCode: 'tenis',
      version: 1,
      published: true,
      config: const TrainingProtocolConfig(
        setCount: 3,
        unitsPerSet: 1,
        prepSeconds: 10,
        shootSeconds: 60,
        collectSeconds: 0,
        restSeconds: 20,
        maxUnitScore: 10,
        entryMode: ScoreEntryMode.flexible,
        mode: TrainingMode.technique,
        archetype: TrainingArchetype.combatRally,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 3,
              athleteKind: null,
            ),
          ),
          trainingProtocolsProvider.overrideWith((ref) async => [protocol]),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(id: 'club-1', name: 'Swan Tenis'),
          ),
          teamsProvider.overrideWith(
            (ref) async => const [
              TeamRow(id: 'tennis', name: 'Tenis A', sportCode: 'tenis'),
              TeamRow(id: 'swim', name: 'Yüzme A', sportCode: 'yuzme'),
              TeamRow(id: 'legacy', name: 'Genel Grup'),
            ],
          ),
          sportContextOptionsProvider.overrideWithValue(
            AsyncData(catalogSportsFor(['tenis'])),
          ),
          selectedSportContextProvider.overrideWith((ref) => 'tenis'),
        ],
        child: const MaterialApp(home: ProtocolListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oturumu Başlat'));
    await tester.pumpAndSettle();

    expect(find.text('Antrenman kapsamı'), findsOneWidget);
    expect(find.text('Swan Tenis · Tenis'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    expect(find.text('Tenis A'), findsOneWidget);
    expect(find.text('Genel Grup'), findsOneWidget);
    expect(find.text('Yüzme A'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/operations/pro_club_context_selector.dart';
import 'package:swansport_pro/features/operations/pro_feature_host.dart';
import 'package:swansport_pro/features/operations/pro_operations_gate.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

const _clubs = [
  ClubRef(id: 'one', name: 'Bir Kulüp', role: 'coach'),
  ClubRef(id: 'two', name: 'İki Kulüp', role: 'club_admin'),
];

void main() {
  test('authorized clubs exclude inactive and non-operation memberships',
      () async {
    final container = ProviderContainer(
      overrides: [
        myClubsProvider.overrideWith((ref) async => const [
              ClubRef(id: 'coach', name: 'Antrenör', role: 'coach'),
              ClubRef(id: 'athlete', name: 'Sporcu', role: 'athlete'),
              ClubRef(
                id: 'inactive',
                name: 'Pasif',
                role: 'club_admin',
                status: 'inactive',
              ),
            ]),
      ],
    );
    addTearDown(container.dispose);
    await container.read(myClubsProvider.future);
    final result = container.read(proAuthorizedClubsProvider).requireValue;
    expect(result.map((club) => club.id), ['coach']);
  });

  testWidgets('one club auto-selects and multiple clubs expose selector',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        proAuthorizedClubsProvider.overrideWith(
          (ref) => const AsyncData(_clubs),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProOperationsFeatureHost(
            child: Scaffold(body: ProClubContextSelector()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(container.read(selectedClubIdProvider), 'one');
    expect(find.byKey(const Key('pro-club-selector')), findsOneWidget);
  });

  testWidgets('dirty club switch cancels once and then confirms',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        proAuthorizedClubsProvider.overrideWith(
          (ref) => const AsyncData(_clubs),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedClubIdProvider.notifier).state = 'one';
    container
        .read(proDirtyStateCoordinatorProvider)
        .register('fixture')
        .markDirty();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProOperationsFeatureHost(
            child: Scaffold(body: ProClubContextSelector()),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('pro-club-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İki Kulüp').last);
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler var'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(container.read(selectedClubIdProvider), 'one');

    await tester.tap(find.byKey(const Key('pro-club-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İki Kulüp').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kulübü değiştir'));
    await tester.pumpAndSettle();
    expect(container.read(selectedClubIdProvider), 'two');
  });

  testWidgets('operations gate shows explicit message without active authority',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          proAuthorizedClubsProvider.overrideWith(
            (ref) => const AsyncData(<ClubRef>[]),
          ),
        ],
        child: const MaterialApp(
          home: ProOperationsGate(child: Text('PRIVATE OPERATION')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yetkisiz Erişim'), findsOneWidget);
    expect(find.textContaining('aktif kulüp operasyonu'), findsOneWidget);
    expect(find.text('PRIVATE OPERATION'), findsNothing);
  });
}

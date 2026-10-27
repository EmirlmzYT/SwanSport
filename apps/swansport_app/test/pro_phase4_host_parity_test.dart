import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/pro_operations/swan_pro_feature_host.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('SwanSport host routes shared specialist inventory by typed port',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              clubOperationsAuthority: [
                ClubOperationsAuthority(
                  clubId: 'club-1',
                  inventoryRead: true,
                  inventoryWrite: true,
                  healthRead: false,
                  planningRead: false,
                ),
              ],
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.clubStaffOperations,
            }),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'kit_manager',
            ),
          ),
        ],
        child: MaterialApp(
          routes: {
            '/kulup/malzeme-zimmet': (_) =>
                const Scaffold(body: Text('ENVANTER_HEDEFI')),
          },
          home: const Scaffold(
            body: SwanProFeatureHost(
              child: SharedClubStaffOperationsPanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Envanter ve Zimmet'));
    await tester.pumpAndSettle();
    expect(find.text('ENVANTER_HEDEFI'), findsOneWidget);
  });
}

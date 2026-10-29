import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/operations/pro_feature_host.dart';
import 'package:swansport_pro/workspaces/pro_workspace.dart';
import 'package:swansport_pro/workspaces/pro_workspace_controller.dart';
import 'package:swansport_pro/workspaces/pro_workspace_switcher.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('dirty workspace switch can cancel then confirm', (tester) async {
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: true,
            clubRole: 'club_admin',
            coachLevel: 0,
            athleteKind: null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final registration =
        container.read(proDirtyStateCoordinatorProvider).register('fixture');
    registration.markDirty();
    addTearDown(registration.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProOperationsFeatureHost(
            child: Scaffold(body: ProWorkspaceSwitcher()),
          ),
        ),
      ),
    );
    expect(container.read(selectedProWorkspaceProvider), ProWorkspace.club);
    await tester
        .tap(find.byKey(const ValueKey('pro_workspace_dropdown_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Platform').last);
    await tester.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler var'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(container.read(selectedProWorkspaceProvider), ProWorkspace.club);

    await tester
        .tap(find.byKey(const ValueKey('pro_workspace_dropdown_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Platform').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alanı değiştir'));
    await tester.pumpAndSettle();
    expect(container.read(selectedProWorkspaceProvider), ProWorkspace.platform);
    expect(container.read(selectedClubIdProvider), isNull);
  });
}

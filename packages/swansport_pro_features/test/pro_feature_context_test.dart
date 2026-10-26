import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  test('context key equality includes user, workspace, and club', () {
    const original = ProFeatureContextKey(
      userId: 'user-1',
      workspace: 'club',
      clubId: 'club-1',
    );

    expect(
      original,
      const ProFeatureContextKey(
        userId: 'user-1',
        workspace: 'club',
        clubId: 'club-1',
      ),
    );
    expect(
      original,
      isNot(
        const ProFeatureContextKey(
          userId: 'user-2',
          workspace: 'club',
          clubId: 'club-1',
        ),
      ),
    );
    expect(
      original,
      isNot(
        const ProFeatureContextKey(
          userId: 'user-1',
          workspace: 'coaching',
          clubId: 'club-1',
        ),
      ),
    );
    expect(
      original,
      isNot(
        const ProFeatureContextKey(
          userId: 'user-1',
          workspace: 'club',
          clubId: 'club-2',
        ),
      ),
    );
  });

  test('context invalidation targets are explicit and unique', () {
    expect(proFeatureInvalidationTargets, contains('selectedClubIdProvider'));
    expect(proFeatureInvalidationTargets, contains('teamRosterProvider'));
    expect(proFeatureInvalidationTargets, contains('attendanceQueueProvider'));
    expect(proFeatureInvalidationTargets, contains('trainingSessionProvider'));
    expect(
      proFeatureInvalidationTargets.toSet(),
      hasLength(proFeatureInvalidationTargets.length),
    );
  });

  testWidgets('context boundary disposes the old keyed subtree',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final disposedContexts = <ProFeatureContextKey?>[];
    const first = ProFeatureContextKey(
      userId: 'user-1',
      workspace: 'club',
      clubId: 'club-1',
    );
    const second = ProFeatureContextKey(
      userId: 'user-1',
      workspace: 'club',
      clubId: 'club-2',
    );
    container.read(proFeatureContextProvider.notifier).state = first;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final featureContext = ref.watch(proFeatureContextProvider);
              return ProFeatureContextBoundary(
                contextKey: featureContext,
                child: _DisposeProbe(
                  contextKey: featureContext,
                  onDispose: disposedContexts.add,
                ),
              );
            },
          ),
        ),
      ),
    );

    container.read(proFeatureContextProvider.notifier).state = second;
    await tester.pump();

    expect(disposedContexts, [first]);
    expect(find.text('club-2'), findsOneWidget);
  });
}

final class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe({required this.contextKey, required this.onDispose});

  final ProFeatureContextKey? contextKey;
  final ValueChanged<ProFeatureContextKey?> onDispose;

  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

final class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  void dispose() {
    widget.onDispose(widget.contextKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.contextKey?.clubId ?? '-');
}

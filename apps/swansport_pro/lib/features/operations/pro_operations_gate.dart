import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../workspaces/pro_workspace_controller.dart';
import 'pro_club_context_selector.dart';
import 'pro_feature_host.dart';

class ProOperationsGate extends ConsumerWidget {
  const ProOperationsGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    final clubsAsync = ref.watch(proAuthorizedClubsProvider);
    return clubsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text(classifyOperationError(error).userMessage)),
      ),
      data: (clubs) {
        if (clubs.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu çalışma alanında aktif kulüp operasyon yetkin bulunmuyor.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final selectedId = ref.watch(selectedClubIdProvider);
        final selected =
            clubs.where((item) => item.id == selectedId).firstOrNull;
        if (selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedClubIdProvider.notifier).state = clubs.first.id;
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final club = selected;
        final userId =
            ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
        return ProFeatureContextBoundary(
          contextKey: ProFeatureContextKey(
            userId: userId,
            workspace: workspace?.name ?? 'none',
            clubId: club.id,
          ),
          child: ProOperationsFeatureHost(child: child),
        );
      },
    );
  }
}

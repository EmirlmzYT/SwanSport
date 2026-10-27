import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';
import 'pro_feature_host.dart';

class ProTasksScreen extends ConsumerWidget {
  const ProTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    final isClubOrCoaching =
        workspace == ProWorkspace.club || workspace == ProWorkspace.coaching;
    final isFederation = workspace == ProWorkspace.federation;
    final isReferee = workspace == ProWorkspace.referee;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Görevler',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (!isClubOrCoaching && !isFederation && !isReferee)
            const Text('Bu çalışma alanı için operasyon görevi bulunmuyor.'),
          if (isClubOrCoaching)
            const ProOperationsFeatureHost(
              child: SharedClubOperationsPanel(),
            ),
          if (isFederation)
            const ProOperationsFeatureHost(
              child: SharedFederationOperationsPanel(),
            ),
          if (isReferee)
            const ProOperationsFeatureHost(
              child: SharedRefereeOperationsPanel(),
            ),
        ],
      ),
    );
  }
}

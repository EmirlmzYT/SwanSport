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
    final operational =
        workspace == ProWorkspace.club || workspace == ProWorkspace.coaching;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Görevler',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (!operational)
            const Text('Bu çalışma alanı için operasyon görevi bulunmuyor.'),
          if (operational)
            const ProOperationsFeatureHost(
              child: SharedClubOperationsPanel(),
            ),
        ],
      ),
    );
  }
}

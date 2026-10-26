import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';

class ProTasksScreen extends ConsumerWidget {
  const ProTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    final flags = ref.watch(featureFlagsProvider).valueOrNull;
    final operational =
        workspace == ProWorkspace.club || workspace == ProWorkspace.coaching;
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Görevler',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (!operational ||
              !(flags?.has(FeatureFlags.coachWorkspace) ?? false))
            const Text('Bu çalışma alanı için operasyon görevi bulunmuyor.'),
          if (operational && (flags?.has(FeatureFlags.teamHub) ?? false))
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Takımları ve kadroları yönet'),
              onTap: () => context.push('/operasyon/takimlar'),
            ),
          if (operational &&
              (flags?.has(FeatureFlags.attendanceOperations) ?? false)) ...[
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Yoklama al'),
              onTap: () => context.push('/operasyon/yoklama'),
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Devam raporlarını aç'),
              onTap: () => context.push('/operasyon/devam'),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';
import '../../app/pro_theme.dart';
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
    final isAccounting = workspace == ProWorkspace.accounting;
    final isFacility = workspace == ProWorkspace.facility;
    final isPlatform = workspace == ProWorkspace.platform;
    final access = ref.watch(swanAccessProvider);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          color: ProTheme.surfaceRaised,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.task_alt_rounded,
                            color: ProTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Operasyon Merkezi',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: ProTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${workspace?.label ?? 'Profesyonel'} çalışma alanındaki görev ve hızlı işlemler',
                              style: const TextStyle(color: ProTheme.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isClubOrCoaching)
                    ProOperationsFeatureHost(
                      child: Column(
                        children: [
                          if (access.hasActiveClubStaffMembership)
                            const SharedClubOperationsPanel(),
                          if (access.hasOperationalClubRole)
                            const SharedClubStaffOperationsPanel(),
                        ],
                      ),
                    ),
                  if (isFederation)
                    const ProOperationsFeatureHost(
                      child: SharedFederationOperationsPanel(),
                    ),
                  if (isReferee)
                    const ProOperationsFeatureHost(
                      child: SharedRefereeOperationsPanel(),
                    ),
                  if (isAccounting)
                    const ProOperationsFeatureHost(
                      child: SharedAccountingOperationsPanel(),
                    ),
                  if (isFacility)
                    const ProOperationsFeatureHost(
                      child: SharedFacilityOperationsPanel(),
                    ),
                  if (isPlatform)
                    const ProOperationsFeatureHost(
                      child: SharedPlatformOperationsPanel(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

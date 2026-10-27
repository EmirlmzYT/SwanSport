import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../workspaces/pro_workspace_controller.dart';
import '../operations/pro_club_context_selector.dart';
import '../operations/pro_feature_host.dart';

class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    if (workspace == null) {
      return const Scaffold(
          body: Center(child: Text('Çalışma alanı bulunamadı.')));
    }
    final supportsFederation = workspace.supportsFederationOperations;
    final supportsReferee = workspace.supportsRefereeOperations;
    final supportsAccounting = workspace.supportsAccountingOperations;
    final supportsFacility = workspace.supportsFacilityOperations;
    final supportsPlatform = workspace.supportsPlatformOperations;
    final access = ref.watch(swanAccessProvider);
    final clubs = ref.watch(proAuthorizedClubsProvider);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${workspace.label} Paneli',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Seçili çalışma alanı: ${workspace.label}',
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          if (supportsFederation)
            const ProOperationsFeatureHost(
              child: SharedFederationOperationsPanel(),
            )
          else if (supportsReferee)
            const ProOperationsFeatureHost(
              child: SharedRefereeOperationsPanel(),
            )
          else if (supportsAccounting)
            const ProOperationsFeatureHost(
              child: SharedAccountingOperationsPanel(),
            )
          else if (supportsFacility)
            const ProOperationsFeatureHost(
              child: SharedFacilityOperationsPanel(),
            )
          else if (supportsPlatform)
            const ProOperationsFeatureHost(
              child: SharedPlatformOperationsPanel(),
            )
          else
            clubs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Text(classifyOperationError(error).userMessage),
              data: (items) {
                if (items.isEmpty) {
                  return const _InfoCard(
                    icon: Icons.lock_person_outlined,
                    title: 'Aktif kulüp operasyon yetkisi yok',
                    body:
                        'Bu çalışma alanını açan kimliğin var ancak aktif kulüp yöneticisi veya antrenör üyeliğin bulunmuyor.',
                  );
                }
                return ProOperationsFeatureHost(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (access.hasActiveClubStaffMembership)
                        const SharedClubOperationsPanel(),
                      if (access.hasActiveClubStaffMembership &&
                          access.hasOperationalClubRole)
                        const SizedBox(height: 24),
                      if (access.hasOperationalClubRole)
                        const SharedClubStaffOperationsPanel(),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          const _InfoCard(
            icon: Icons.security_outlined,
            title: 'Sunucu Yetkisi Korunuyor',
            body:
                'Ekran görünürlüğü özellik bayraklarıyla, gerçek veri ve işlem yetkisi mevcut RLS ve RPC kontrolleriyle korunur.',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF38BDF8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(body),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

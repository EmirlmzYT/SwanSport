import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../app/pro_theme.dart';
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            children: [
              _WorkspaceHeader(workspaceLabel: workspace.label),
              const SizedBox(height: 24),
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
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _InfoCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Operasyon bilgileri alınamadı',
                    body: classifyOperationError(error).userMessage,
                    tone: _InfoTone.danger,
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _InfoCard(
                        icon: Icons.lock_person_outlined,
                        title: 'Aktif kulüp operasyon yetkisi yok',
                        body:
                            'Bu çalışma alanını açan kimliğin var ancak aktif kulüp yöneticisi veya antrenör üyeliğin bulunmuyor.',
                        tone: _InfoTone.warning,
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
                            const SizedBox(height: 28),
                          if (access.hasOperationalClubRole)
                            const SharedClubStaffOperationsPanel(),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 22),
              const _InfoCard(
                icon: Icons.verified_user_outlined,
                title: 'Yetki sınırların aktif',
                body:
                    'Gördüğün modüller hesabının güncel kapsamına göre açılır; veri ve işlem izinleri sunucudaki RLS ve RPC kurallarıyla korunur.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.workspaceLabel});

  final String workspaceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12314A), Color(0xFF0E1B2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ProTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: ProTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: ProTheme.primary.withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(
              Icons.space_dashboard_rounded,
              color: ProTheme.primary,
              size: 27,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$workspaceLabel Paneli',
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Bugünkü operasyonlarını tek ekrandan yönet.',
                  style: TextStyle(color: ProTheme.muted, height: 1.4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: ProTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ProTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 7),
                Text(
                  'Aktif',
                  style: TextStyle(
                    color: ProTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _InfoTone { neutral, warning, danger }

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.tone = _InfoTone.neutral,
  });

  final IconData icon;
  final String title;
  final String body;
  final _InfoTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      _InfoTone.neutral => ProTheme.secondary,
      _InfoTone.warning => const Color(0xFFF59E0B),
      _InfoTone.danger => const Color(0xFFF87171),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ProTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: ProTheme.muted,
                    height: 1.4,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

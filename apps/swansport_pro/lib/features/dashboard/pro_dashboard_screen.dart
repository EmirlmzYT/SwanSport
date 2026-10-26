import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../workspaces/pro_workspace_controller.dart';
import '../operations/pro_club_context_selector.dart';

class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    if (workspace == null) {
      return const Scaffold(
          body: Center(child: Text('Çalışma alanı bulunamadı.')));
    }
    final flags = ref.watch(featureFlagsProvider).valueOrNull;
    final supportsOperations = workspace.supportsClubOperations;
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
          if (!supportsOperations)
            const _InfoCard(
              icon: Icons.schedule_outlined,
              title: 'Bu çalışma alanı sonraki fazda açılacak',
              body:
                  'Takvim ve Gelen Kutusu yerleri korunuyor. Bu fazda gerçek kulüp ve antrenör operasyonları açılıyor.',
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
                final coachEnabled =
                    flags?.has(FeatureFlags.coachWorkspace) ?? false;
                if (!coachEnabled) {
                  return const _InfoCard(
                    icon: Icons.lock_clock_outlined,
                    title: 'Operasyonlar kademeli yayında',
                    body:
                        'Kulüp ve antrenör operasyonları hesabın için henüz açılmadı.',
                  );
                }
                return Column(
                  children: [
                    if (flags?.has(FeatureFlags.teamHub) ?? false)
                      _OperationCard(
                        icon: Icons.groups_outlined,
                        title: 'Takımlar ve Kadrolar',
                        body: 'Takımları görüntüle, kadro operasyonlarına geç.',
                        onTap: () => context.push('/operasyon/takimlar'),
                      ),
                    if (flags?.has(FeatureFlags.attendanceOperations) ??
                        false) ...[
                      const SizedBox(height: 12),
                      _OperationCard(
                        icon: Icons.fact_check_outlined,
                        title: 'Canlı Yoklama',
                        body: 'İyimser sürüm ve güvenli tekrar ile yoklama al.',
                        onTap: () => context.push('/operasyon/yoklama'),
                      ),
                      const SizedBox(height: 12),
                      _OperationCard(
                        icon: Icons.analytics_outlined,
                        title: 'Yoklama Geçmişi',
                        body: 'Katılım oranlarını ve riskli sporcuları incele.',
                        onTap: () => context.push('/operasyon/devam'),
                      ),
                    ],
                  ],
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

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          minVerticalPadding: 16,
          leading: Icon(icon, color: const Color(0xFF38BDF8)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(body),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
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

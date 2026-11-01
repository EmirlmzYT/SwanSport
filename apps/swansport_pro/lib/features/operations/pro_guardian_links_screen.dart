import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../widgets/pro_ui_components.dart';

class ProGuardianLinksScreen extends ConsumerWidget {
  const ProGuardianLinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(activeClubProvider).valueOrNull;
    if (club == null || club.role != 'club_admin') {
      return const Scaffold(
        body: ProUnauthorizedState(roleName: 'kulüp yöneticisi'),
      );
    }

    final overview = ref.watch(clubGuardianLinkOverviewProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Veli & Sporcu Bağlantıları'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Bağlı Hesaplar'),
              Tab(text: 'Bekleyen Davetler'),
              Tab(text: 'Sporcular'),
            ],
          ),
        ),
        body: overview.when(
          loading: () => const ProLoadingState(
            message: 'Veli bağlantıları yükleniyor…',
          ),
          error: (error, _) => ProErrorState(
            message: classifyOperationError(error).userMessage,
            onRetry: () => ref.invalidate(clubGuardianLinkOverviewProvider),
          ),
          data: (data) => TabBarView(
            children: [
              _LinkedAccountsTab(links: data.links),
              _PendingInvitesTab(invites: data.pendingInvites),
              _AthletesTab(athletes: data.athletes),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedAccountsTab extends StatelessWidget {
  const _LinkedAccountsTab({required this.links});

  final List<ClubGuardianLink> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const ProEmptyState(
        icon: Icons.family_restroom_outlined,
        title: 'Bağlı veli hesabı yok',
        subtitle:
            'Veli davet kodunu kullandığında doğrulanmış bağlantı burada görünür.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final link = links[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.family_restroom_outlined),
            ),
            title: Text(link.athleteDisplayName),
            subtitle: Text('${link.guardianLabel} · ${link.relationship}'),
            trailing: const Tooltip(
              message: 'İletişim ve özel bilgiler gizlidir',
              child: Icon(Icons.privacy_tip_outlined),
            ),
          ),
        );
      },
    );
  }
}

class _PendingInvitesTab extends ConsumerWidget {
  const _PendingInvitesTab({required this.invites});

  final List<PendingGuardianInvite> invites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invites.isEmpty) {
      return const ProEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'Bekleyen veli daveti yok',
        subtitle: 'Kullanılmamış davetler burada görünür.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invites.length,
      itemBuilder: (context, index) {
        final invite = invites[index];
        return Card(
          child: ListTile(
            leading: Icon(
              invite.isExpired
                  ? Icons.timer_off_outlined
                  : Icons.hourglass_top_rounded,
            ),
            title: Text(invite.athleteDisplayName),
            subtitle: Text(
              invite.isExpired
                  ? 'Süresi doldu'
                  : 'Son kullanım: ${_dateTime(invite.expiresAt)}',
            ),
            trailing: IconButton(
              tooltip: 'Daveti iptal et',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _cancel(context, ref, invite),
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    PendingGuardianInvite invite,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Veli daveti iptal edilsin mi?'),
        content: Text(
          '${invite.athleteDisplayName} için üretilen kullanılmamış davet '
          'artık kullanılamayacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Daveti iptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(guardianLinkManagementServiceProvider)
          .cancelPendingInvite(invite.id);
      ref.invalidate(clubGuardianLinkOverviewProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(classifyOperationError(error).userMessage)),
      );
    }
  }
}

class _AthletesTab extends ConsumerWidget {
  const _AthletesTab({required this.athletes});

  final List<ClubGuardianAthlete> athletes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (athletes.isEmpty) {
      return const ProEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Sporcu bulunamadı',
        subtitle: 'Aktif kulübün gerçek sporcu kayıtları burada görünür.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: athletes.length,
      itemBuilder: (context, index) {
        final athlete = athletes[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                athlete.isMinor ? Icons.child_care_outlined : Icons.person,
              ),
            ),
            title: Text(athlete.displayName),
            subtitle: Text(
              '${athlete.guardianCount} bağlı veli'
              '${athlete.isMinor ? ' · Çocuk hesabı maskeli' : ''}',
            ),
            trailing: OutlinedButton.icon(
              onPressed: () => _createInvite(context, ref, athlete),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Davet oluştur'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _createInvite(
    BuildContext context,
    WidgetRef ref,
    ClubGuardianAthlete athlete,
  ) async {
    try {
      final code = await ref
          .read(verificationServiceProvider)
          .createGuardianInvite(athlete.id);
      ref.invalidate(clubGuardianLinkOverviewProvider);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tek kullanımlık veli daveti'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kodu yalnızca ilgili veliyle güvenli bir kanaldan paylaş. '
                'Kod 24 saat geçerlidir.',
              ),
              const SizedBox(height: 16),
              SelectableText(
                code,
                key: const Key('guardian-invite-code'),
                style: Theme.of(dialogContext).textTheme.headlineMedium,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Kopyala'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(classifyOperationError(error).userMessage)),
      );
    }
  }
}

String _dateTime(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

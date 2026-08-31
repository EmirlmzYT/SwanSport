import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import 'coach_accept_sheet.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Kulübe gelen katılım başvuruları — yetkili kabul eder veya reddeder.
class ClubApplicationsScreen extends ConsumerWidget {
  const ClubApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(clubPendingApplicationsProvider);
    final mine = ref.watch(myApplicationsProvider);

    final canReview =
        club != null && (club.role == 'club_admin' || club.role == 'coach');

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(clubPendingApplicationsProvider);
                ref.invalidate(myApplicationsProvider);
                await ref.read(myApplicationsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Text((club?.name ?? 'SWANSPORT').toUpperCase(),
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.4)),
                  const SizedBox(height: 3),
                  Text('Başvurular', style: sora(25, FontWeight.w800, ink)),
                  const SizedBox(height: 18),

                  if (canReview) ...[
                    Text('KULÜBÜNE GELENLER',
                        style: jakarta(
                            11, FontWeight.w700, SwanColors.textSecondary,
                            ls: 1.2)),
                    const SizedBox(height: 10),
                    async.when(
                      loading: premiumLoading,
                      error: (e, _) => premiumError(context, '$e'),
                      data: (list) {
                        if (list.isEmpty) {
                          return _mini('Bekleyen başvuru yok');
                        }
                        return Column(
                            children: list
                                .map((a) => _incoming(context, ref, isDark, a))
                                .toList());
                      },
                    ),
                    const SizedBox(height: 26),
                  ],

                  // Bana gelen kulüp teklifleri
                  ref.watch(myPendingOffersProvider).maybeWhen(
                        data: (offers) => offers.isEmpty
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SANA GELEN TEKLİFLER',
                                      style: jakarta(11, FontWeight.w700,
                                          SwanColors.textSecondary,
                                          ls: 1.2)),
                                  const SizedBox(height: 10),
                                  ...offers.map(
                                      (o) => _offer(context, ref, isDark, o)),
                                  const SizedBox(height: 26),
                                ],
                              ),
                        orElse: () => const SizedBox.shrink(),
                      ),

                  Text('BENİM BAŞVURULARIM',
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.2)),
                  const SizedBox(height: 10),
                  mine.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return _mini(
                            'Henüz başvurun yok. Aramadan bir kulüp bulup '
                            'başvurabilirsin.');
                      }
                      return Column(
                          children:
                              list.map((a) => _mineRow(isDark, a)).toList());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _mini(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: jakarta(12.5, FontWeight.w500, SwanColors.textSecondary)),
      );

  Widget _incoming(BuildContext context, WidgetRef ref, bool isDark,
      ClubApplicationRow a) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profil',
                  arguments: a.profileId),
              child: GradientAvatar(
                  initials: a.initials,
                  size: 42,
                  gradientIndex: (a.personName ?? 'x').length % 4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.personName ?? 'Kişi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(13.5, FontWeight.w800, ink)),
                  Text('${a.roleLabel} olarak katılmak istiyor',
                      style: jakarta(
                          11.5, FontWeight.w500, SwanColors.textSecondary)),
                ],
              ),
            ),
            _mini2(const Color(0xFFF43F5E), Icons.close_rounded,
                () => _run(context, ref, a.id, false)),
            const SizedBox(width: 6),
            _mini2(
                const Color(0xFF10B981),
                Icons.check_rounded,
                () => a.desiredRole == 'coach'
                    ? _acceptCoach(context, ref, a)
                    : _run(context, ref, a.id, true)),
          ]),
          if (a.message != null && a.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A2537)
                    : const Color(0xFFF1F5F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(a.message!,
                  style: jakarta(12, FontWeight.w500, ink)
                      .copyWith(height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini2(Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  /// Kulüpten sana gelen katılım teklifi — kabul/ret sende.
  Widget _offer(BuildContext context, WidgetRef ref, bool isDark,
      ClubApplicationRow a) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFD9860B).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFD9860B).withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFD9860B).withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.mail_rounded,
                  size: 19, color: Color(0xFFD9860B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.clubName ?? 'Kulüp',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(13.5, FontWeight.w800, ink)),
                  Text('${a.roleLabel} olarak katılman için davet etti',
                      style: jakarta(
                          11.5, FontWeight.w500, SwanColors.textSecondary)),
                ],
              ),
            ),
          ]),
          if (a.message != null && a.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(a.message!,
                  style:
                      jakarta(12, FontWeight.w500, ink).copyWith(height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _run(context, ref, a.id, false),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Reddet',
                      style: jakarta(
                          13, FontWeight.w800, SwanColors.textSecondary)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => _run(context, ref, a.id, true),
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [kTealBright, kTeal]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Kabul Et',
                      style: jakarta(13, FontWeight.w800, Colors.white)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _mineRow(bool isDark, ClubApplicationRow a) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final (color, icon) = switch (a.status) {
      'accepted' => (const Color(0xFF10B981), Icons.check_circle_rounded),
      'rejected' => (const Color(0xFFF43F5E), Icons.cancel_rounded),
      _ => (const Color(0xFFD9860B), Icons.schedule_rounded),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.clubName ?? 'Kulüp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(13.5, FontWeight.w800, ink)),
              Text('${a.roleLabel} başvurusu',
                  style: jakarta(
                      11.5, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
        PremiumStatusChip(label: a.statusLabel, color: color, icon: icon),
      ]),
    );
  }

  /// Antrenör başvurusu kabul edilirken kademe ve (1. kademe için) süpervizör
  /// sorulur — hiyerarşi kuralı: 1. kademe tek başına olamaz.
  Future<void> _acceptCoach(BuildContext context, WidgetRef ref,
      ClubApplicationRow a) async {
    final service = ref.read(clubApplicationServiceProvider);
    final supervisors = await service.eligibleSupervisors(a.clubId);
    if (!context.mounted) return;

    final result = await showModalBottomSheet<({int level, String? sup})>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CoachAcceptSheet(
        personName: a.personName ?? 'Antrenör',
        supervisors: supervisors,
      ),
    );
    if (result == null) return;

    try {
      await service.review(a.id, true,
          coachLevel: result.level, supervisorId: result.sup);
      ref.invalidate(clubPendingApplicationsProvider);
      ref.invalidate(clubAthletesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Antrenör kulübe eklendi'), backgroundColor: kTeal));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  Future<void> _run(
      BuildContext context, WidgetRef ref, String id, bool accept) async {
    try {
      await ref.read(clubApplicationServiceProvider).review(id, accept);
      ref.invalidate(clubPendingApplicationsProvider);
      ref.invalidate(clubAthletesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(accept ? 'Başvuru kabul edildi' : 'Başvuru reddedildi'),
            backgroundColor: kTeal));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }
}

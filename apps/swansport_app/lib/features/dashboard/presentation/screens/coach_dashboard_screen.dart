import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../athlete_workspace/presentation/screens/athlete_home_screen.dart';
import '../../../demo/demo_role.dart';
import '../../../home/presentation/screens/guardian_home_screen.dart';
import '../../../home/presentation/screens/member_home_screen.dart';
import '../../../verification/presentation/club_pending_screen.dart';

/// Antrenör Paneli — Stitch "Calm Athletic Modernism" Operasyon & Kontrol Merkezi.
class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final demoRole = ref.watch(demoRoleProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;

    // Rol henüz yüklenmediyse bekle
    if (demoRole == null && profileAsync.isLoading) {
      return Scaffold(backgroundColor: c.bg, body: premiumLoading());
    }

    // Role göre yönlendirme (Sözleşme korunur)
    final isAthleteView = demoRole == DemoRole.athleteLicensed ||
        demoRole == DemoRole.athleteIndividual ||
        (demoRole == null && profile?.role == 'athlete');
    if (isAthleteView) return const AthleteHomeScreen();

    final isGuardianView = demoRole == DemoRole.guardian ||
        (demoRole == null && profile?.role == 'parent');
    if (isGuardianView) return const GuardianHomeScreen();

    final isMemberView = demoRole == DemoRole.member ||
        (demoRole == null &&
            profile != null &&
            profile.role != 'club_admin' &&
            profile.role != 'coach');
    if (isMemberView) return const MemberHomeScreen();

    if (demoRole == null && club != null && club.isPending) {
      return const ClubPendingScreen();
    }

    final athletes = ref.watch(clubAthletesProvider);
    final events = ref.watch(eventsProvider);

    final clubName = club?.name ?? 'Kulüp seçilmedi';
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(clubAthletesProvider);
              ref.invalidate(eventsProvider);
              await ref.read(eventsProvider.future);
            },
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('SwanSport', style: SwanType.h2(c.ink))),
                    const InboxActions()
                  ]),
                  const SizedBox(height: 16),
                  Text('İyi çalışmalar,', style: SwanType.h3(c.ink)),
                  Text(clubName, style: SwanType.bodySm(c.inkMuted)),
                  const SizedBox(height: 16),
                  athletes.when(
                      loading: premiumLoading,
                      error: (e, _) => premiumError(context, '$e'),
                      data: (rows) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Aktif sporcu'),
                          trailing:
                              Text('${rows.where((a) => a.isActive).length}'),
                          onTap: () =>
                              Navigator.pushNamed(context, '/athletes'))),
                  const SizedBox(height: 12),
                  Text('Etkinlik', style: SwanType.h3(c.ink)),
                  events.when(
                      loading: premiumLoading,
                      error: (e, _) => premiumError(context, '$e'),
                      data: (rows) {
                        final upcoming = rows
                            .where((e) => e.endsAt != null
                                ? e.endsAt!.isAfter(DateTime.now())
                                : e.startsAt.isAfter(DateTime.now()))
                            .toList()
                          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                        return Column(children: [
                          if (upcoming.isEmpty)
                            Text('Yaklaşan etkinlik yok.',
                                style: SwanType.bodySm(c.inkMuted)),
                          for (final event in upcoming.take(3))
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(event.title),
                                subtitle: Text(
                                    '${event.startsAt.day}.${event.startsAt.month}.${event.startsAt.year} · ${event.startsAt.hour.toString().padLeft(2, '0')}:${event.startsAt.minute.toString().padLeft(2, '0')}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pushNamed(
                                    context, '/etkinlik-detay',
                                    arguments: event.id)),
                        ]);
                      }),
                  TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/calendar'),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Takvimi aç')),
                  const SizedBox(height: 16),
                  for (final action in [
                    ('Yoklama al', '/attendance', Icons.fact_check_outlined),
                    ('Kulüp kadrosu', '/athletes', Icons.groups_outlined),
                    ('Belge kasası', '/documents', Icons.folder_outlined),
                    (
                      'Uygunluk durumu',
                      '/medical-center',
                      Icons.health_and_safety_outlined
                    ),
                  ])
                    ListTile(
                        title: Text(action.$1),
                        leading: Icon(action.$3),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(context, action.$2)),
                ])),
      ))),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

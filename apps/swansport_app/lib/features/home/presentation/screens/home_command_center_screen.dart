import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_actions.dart';
import '../../../demo/demo_role.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Komuta Merkezi (Ekran 0) — Supabase verisine bağlı, premium (v3).
class HomeCommandCenterScreen extends ConsumerWidget {
  const HomeCommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final athletes = ref.watch(clubAthletesProvider);
    final events = ref.watch(eventsProvider);
    final anns = ref.watch(announcementsProvider);
    final isAdmin = ref.watch(effectiveIsPlatformAdminProvider);
    final pending = ref.watch(pendingCredentialsProvider);
    final demoLabel = ref.watch(effectiveRoleLabelProvider);

    int n(AsyncValue<List> v) =>
        v.maybeWhen(data: (l) => l.length, orElse: () => 0);

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
                ref.invalidate(clubAthletesProvider);
                ref.invalidate(eventsProvider);
                ref.invalidate(announcementsProvider);
                await ref.read(eventsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 132),
                children: [
                  Row(children: [
                    const _Crest(),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(club?.name ?? 'SwanSport',
                              style: SwanType.bodySm(ink, w: FontWeight.w800)),
                          Text(demoLabel ?? _role(profile?.role),
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const InboxActions(),
                  ]),
                  const SizedBox(height: 18),
                  Text('Komuta Merkezi', style: SwanType.h3(ink)),
                  const SizedBox(height: 4),
                  Text('Merhaba, ${profile?.firstName ?? 'Antrenör'}',
                      style: SwanType.h2(ink)),
                  const SizedBox(height: 16),
                  // KPI şeridi (gerçek sayılar)
                  Container(
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: line),
                    ),
                    child: Row(children: [
                      _kpi(ink, '${n(athletes)}', 'Sporcu', ink),
                      _div(line),
                      _kpi(ink, '${n(events)}', 'Etkinlik', ink),
                      _div(line),
                      _kpi(ink, '${n(anns)}', 'Duyuru', ink),
                      if (isAdmin) ...[
                        _div(line),
                        _kpi(ink, '${n(pending)}', 'Onay',
                            SwanPalette.light.warning),
                      ],
                    ]),
                  ),

                  _label('BUGÜNÜN AJANDASI', ink),
                  events.when(
                    loading: () => _mini('Yükleniyor…'),
                    error: (_, __) => _mini('Yüklenemedi'),
                    data: (list) {
                      final up = list.take(2).toList();
                      if (up.isEmpty) return _mini('Yaklaşan etkinlik yok');
                      return Column(
                          children: up
                              .map((e) => _agenda(
                                  isDark, e.startsAt, e.title, e.place ?? '—'))
                              .toList());
                    },
                  ),

                  if (isAdmin) ...[
                    _label('BEKLEYEN ONAYLAR', ink),
                    pending.when(
                      loading: () => _mini('Yükleniyor…'),
                      error: (_, __) => _mini('Yüklenemedi'),
                      data: (list) {
                        if (list.isEmpty) return _mini('Bekleyen onay yok');
                        return GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/onay-paneli'),
                          child: _approvalCard(isDark, list.length),
                        );
                      },
                    ),
                  ],

                  _label('HIZLI İŞLEMLER', ink),
                  const QuickActions(actions: [
                    QuickAction(
                        icon: Icons.checklist_rounded,
                        label: 'Yoklama',
                        route: '/attendance'),
                    QuickAction(
                        icon: Icons.campaign_rounded,
                        label: 'Duyuru',
                        route: '/announcements'),
                    QuickAction(
                        icon: Icons.groups_rounded,
                        label: 'Kadro',
                        route: '/athletes'),
                    QuickAction(
                        icon: Icons.calendar_month_rounded,
                        label: 'Takvim',
                        route: '/calendar'),
                    QuickAction(
                        icon: Icons.bar_chart_rounded,
                        label: 'Performans',
                        route: '/performance-analytics'),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  String _role(String? r) => switch (r) {
        'club_admin' => 'Yönetici',
        'coach' => 'Antrenör',
        'athlete' => 'Sporcu',
        'parent' => 'Veli',
        _ => 'Üye',
      };

  Widget _kpi(Color c, String n, String l, Color numColor) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(children: [
            Text(n, style: SwanType.h3(numColor)),
            const SizedBox(height: 1),
            Text(l,
                style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
          ]),
        ),
      );

  Widget _div(Color line) => Container(width: 1, height: 34, color: line);

  Widget _label(String t, Color ink) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(t,
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
      );

  Widget _mini(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: SwanType.caption(SwanColors.textSecondary)),
      );

  Widget _agenda(bool isDark, DateTime t, String title, String place) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line)),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Text(hm, style: SwanType.h3(kTeal)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.bodySm(ink, w: FontWeight.w700)),
              Text(place,
                  style:
                      SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _approvalCard(bool isDark, int count) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: SwanPalette.light.warning.withValues(alpha: .4))),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: SwanPalette.light.warning.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.admin_panel_settings_rounded,
              color: SwanPalette.light.warning, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('$count doğrulama seni bekliyor',
              style: SwanType.bodySm(ink, w: FontWeight.w700)),
        ),
        Icon(Icons.chevron_right_rounded,
            color: SwanColors.textSecondary, size: 20),
      ]),
    );
  }


}

class _Crest extends StatelessWidget {
  const _Crest();
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kTeal, kTealDeep]),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text('K', style: SwanType.h3(Colors.white)),
      );
}

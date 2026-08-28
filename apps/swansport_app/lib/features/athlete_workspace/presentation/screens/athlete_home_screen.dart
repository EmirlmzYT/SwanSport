import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';

/// Sporcu Ana Ekranı — sporcunun kendi gözünden (premium v3).
///
/// Antrenör panelinden farklı: kadro/yönetim yok. Sporcuya ait yaklaşan
/// antrenman/maç, duyurular ve kişisel kısayollar (Takvim, Performansım,
/// Belgelerim) gösterilir. Demo "Sporcu" rolünde ve gerçek athlete hesabında
/// `/dashboard` bu ekrana yönlendirir.
class AthleteHomeScreen extends ConsumerWidget {
  const AthleteHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final events = ref.watch(eventsProvider);
    final anns = ref.watch(announcementsProvider);

    final name = profile?.firstName ?? 'Sporcu';
    final initials = profile?.initials ?? 'S';

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
                ref.invalidate(eventsProvider);
                ref.invalidate(announcementsProvider);
                await ref.read(eventsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 132),
                children: [
                  // Üst bar
                  Row(children: [
                    GradientAvatar(initials: initials, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.fullName ?? 'Sporcu',
                              style: jakarta(14, FontWeight.w800, ink)),
                          Text(
                              club?.name != null ? 'Sporcu · ${club!.name}' : 'Sporcu',
                              style: jakarta(11, FontWeight.w600,
                                  SwanColors.textSecondary)),
                        ],
                      ),
                    ),
                    _bell(surf, line),
                  ]),
                  const SizedBox(height: 18),

                  Text(_todayLabel().toUpperCase(),
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.4)),
                  const SizedBox(height: 4),
                  Text('Merhaba, $name',
                      style: sora(25, FontWeight.w800, ink)),
                  const SizedBox(height: 16),

                  // Sıradaki antrenman/maç — hero
                  events.when(
                    loading: () => _heroSkeleton(surf, line),
                    error: (_, __) => _heroEmpty(isDark, 'Program yüklenemedi'),
                    data: (list) {
                      final now = DateTime.now();
                      final upcoming = list
                          .where((e) => e.startsAt
                              .isAfter(now.subtract(const Duration(hours: 3))))
                          .toList()
                        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
                      if (upcoming.isEmpty) {
                        return _heroEmpty(isDark, 'Yaklaşan antrenman yok');
                      }
                      return _hero(upcoming.first);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Kısayollar
                  Text('KISAYOLLAR',
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.2)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _quick(context, isDark, Icons.calendar_month_rounded,
                        'Takvim', '/calendar'),
                    const SizedBox(width: 10),
                    _quick(context, isDark, Icons.bar_chart_rounded,
                        'Performansım', '/performance-analytics'),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _quick(context, isDark, Icons.campaign_rounded, 'Duyurular',
                        '/announcements'),
                    const SizedBox(width: 10),
                    _quick(context, isDark, Icons.folder_rounded, 'Belgelerim',
                        '/documents'),
                  ]),

                  // Yaklaşan program
                  _label('YAKLAŞAN PROGRAM', ink),
                  events.when(
                    loading: () => _mini('Yükleniyor…'),
                    error: (_, __) => _mini('Yüklenemedi'),
                    data: (list) {
                      final now = DateTime.now();
                      final up = (list
                          .where((e) => e.startsAt
                              .isAfter(now.subtract(const Duration(hours: 3))))
                          .toList()
                        ..sort((a, b) => a.startsAt.compareTo(b.startsAt)))
                          .skip(1)
                          .take(3)
                          .toList();
                      if (up.isEmpty) return _mini('Başka etkinlik yok');
                      return Column(
                          children: up
                              .map((e) => _agenda(isDark, e.startsAt, e.title,
                                  e.place ?? _kindLabel(e.kind)))
                              .toList());
                    },
                  ),

                  // Duyurular
                  _label('KULÜP DUYURULARI', ink),
                  anns.when(
                    loading: () => _mini('Yükleniyor…'),
                    error: (_, __) => _mini('Yüklenemedi'),
                    data: (list) {
                      if (list.isEmpty) return _mini('Duyuru yok');
                      return Column(
                          children: list
                              .take(3)
                              .map((a) => _annCard(isDark, a.title, a.body,
                                  a.pinned))
                              .toList());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: 0,
        onSelect: (i) {
          if (i == 1) Navigator.pushNamed(context, '/calendar');
          if (i == 3) Navigator.pushNamed(context, '/athletes');
          if (i == 4) Navigator.pushNamed(context, '/profil');
        },
        onAction: () => Navigator.pushNamed(context, '/calendar'),
      ),
    );
  }

  // ------------------------------------------------------------- parçalar
  Widget _hero(EventRow e) {
    final d = e.startsAt;
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kTealBright, kTeal, kTealDeep],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: kTeal.withValues(alpha: .3),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('SIRADAKİ · ${_kindLabel(e.kind).toUpperCase()}',
                  style: jakarta(10, FontWeight.w800, Colors.white, ls: .5)),
            ),
            const Spacer(),
            const Icon(Icons.sports_rounded, color: Colors.white, size: 20),
          ]),
          const SizedBox(height: 16),
          Text(e.title, style: sora(21, FontWeight.w800, Colors.white)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text('${_dayLabel(d)} · $hm',
                style: jakarta(12.5, FontWeight.w600, Colors.white)),
            const SizedBox(width: 14),
            if (e.place != null) ...[
              const Icon(Icons.place_rounded, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(e.place!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(12.5, FontWeight.w600, Colors.white)),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _heroEmpty(bool isDark, String text) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.event_available_rounded,
              color: kTeal, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: jakarta(14, FontWeight.w700, ink)),
              const SizedBox(height: 2),
              Text('Antrenörün program eklediğinde burada görürsün.',
                  style: jakarta(
                      11.5, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _heroSkeleton(Color surf, Color line) => Container(
        height: 120,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: kTeal, strokeWidth: 2)),
      );

  Widget _quick(BuildContext context, bool isDark, IconData icon, String label,
      String route) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line)),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: kTeal, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(12.5, FontWeight.w700, ink)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t, Color ink) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(t,
            style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                ls: 1.2)),
      );

  Widget _mini(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: jakarta(12.5, FontWeight.w500, SwanColors.textSecondary)),
      );

  Widget _agenda(bool isDark, DateTime t, String title, String place) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
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
          child: Text(hm, style: sora(12, FontWeight.w800, kTeal)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: jakarta(13, FontWeight.w700, ink)),
              Text('${_dayLabel(t)} · $place',
                  style:
                      jakarta(11, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _annCard(bool isDark, String title, String body, bool pinned) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (pinned) ...[
              const Icon(Icons.push_pin_rounded, size: 14, color: kCoral),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(13, FontWeight.w800, ink)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: jakarta(11.5, FontWeight.w500, SwanColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _bell(Color surf, Color line) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: line)),
        child: Icon(Icons.notifications_none_rounded,
            size: 20, color: SwanColors.textSecondary),
      );

  // ------------------------------------------------------------- yardımcılar
  String _todayLabel() {
    final n = DateTime.now();
    return '${n.day} ${_month(n.month)} · ${_weekday(n.weekday)}';
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = that.difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '${d.day} ${_month(d.month)}';
  }

  String _kindLabel(String kind) => switch (kind) {
        'match' => 'Maç',
        'training' => 'Antrenman',
        'meeting' => 'Toplantı',
        _ => 'Etkinlik',
      };

  String _month(int m) => const [
        'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
        'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
      ][m - 1];

  String _weekday(int w) => const [
        'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
      ][w - 1];
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';

/// Veli Ana Ekranı — velinin kendi gözünden (premium v3).
///
/// Yönetim yok: bağlı çocuk(lar), çocuğun programı, kulüp duyuruları ve
/// veliye uygun kısayollar (Takvim, Sağlık, Belgeler). Çocuk bağlı değilse
/// davet kodu ile bağlanmaya yönlendirir.
class GuardianHomeScreen extends ConsumerWidget {
  const GuardianHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final children = ref.watch(childrenOverviewProvider);
    final events = ref.watch(eventsProvider);
    final anns = ref.watch(announcementsProvider);

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
                ref.invalidate(childrenOverviewProvider);
                ref.invalidate(eventsProvider);
                ref.invalidate(announcementsProvider);
                await ref.read(eventsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 132),
                children: [
                  Row(children: [
                    GradientAvatar(
                        initials: profile?.initials ?? 'V',
                        size: 46,
                        gradientIndex: 2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.fullName ?? 'Veli',
                              style: jakarta(14, FontWeight.w800, ink)),
                          Text(
                              club?.name != null
                                  ? 'Veli · ${club!.name}'
                                  : 'Veli',
                              style: jakarta(11, FontWeight.w600,
                                  SwanColors.textSecondary)),
                        ],
                      ),
                    ),
                    _bell(surf, line),
                  ]),
                  const SizedBox(height: 18),
                  Text('VELİ PANELİ',
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.4)),
                  const SizedBox(height: 4),
                  Text('Merhaba, ${profile?.firstName ?? 'Veli'}',
                      style: sora(25, FontWeight.w800, ink)),
                  const SizedBox(height: 16),

                  // Bağlı çocuk(lar)
                  children.when(
                    loading: () => _skeleton(surf, line, 96),
                    error: (_, __) => _linkCta(context, isDark,
                        'Çocuk bilgisi yüklenemedi', 'Tekrar dene'),
                    data: (list) {
                      if (list.isEmpty) {
                        return _linkCta(
                            context,
                            isDark,
                            'Henüz çocuğun bağlı değil',
                            'Kulüpten aldığın davet kodunu gir');
                      }
                      return Column(
                          children:
                              list.map((c) => _childCard(context, isDark, c)).toList());
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
                    _quick(context, isDark, Icons.medical_services_rounded,
                        'Sağlık', '/medical-center'),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _quick(context, isDark, Icons.folder_rounded, 'Belgeler',
                        '/documents'),
                    const SizedBox(width: 10),
                    _quick(context, isDark, Icons.family_restroom_rounded,
                        'Veli Bağla', '/veli-bagla'),
                  ]),

                  // Yaklaşan program
                  _label('YAKLAŞAN PROGRAM'),
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
                          .take(3)
                          .toList();
                      if (up.isEmpty) return _mini('Yaklaşan etkinlik yok');
                      return Column(
                          children: up
                              .map((e) => _agenda(isDark, e.startsAt, e.title,
                                  e.place ?? _kindLabel(e.kind)))
                              .toList());
                    },
                  ),

                  // Duyurular
                  _label('KULÜP DUYURULARI'),
                  anns.when(
                    loading: () => _mini('Yükleniyor…'),
                    error: (_, __) => _mini('Yüklenemedi'),
                    data: (list) {
                      if (list.isEmpty) return _mini('Duyuru yok');
                      return Column(
                          children: list
                              .take(3)
                              .map((a) =>
                                  _annCard(isDark, a.title, a.body, a.pinned))
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

  /// Çocuk kartı — kulübü, devam oranı, borcu, sağlık durumu ve sıradaki
  /// etkinliği bir arada.
  ///
  /// Her çocuk kendi kulübüyle gelir: kardeşler farklı kulüplerde olabilir,
  /// eskiden uygulama tek "aktif kulüp" varsaydığı için bu durum kırılıyordu.
  Widget _childCard(BuildContext context, bool isDark, ChildOverview c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(children: [
        Row(children: [
          GradientAvatar(
              initials: c.initials,
              size: 50,
              radius: 16,
              gradientIndex: c.athleteId.hashCode.abs() % 4),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: sora(17, FontWeight.w800, ink)),
                const SizedBox(height: 2),
                Text(
                    [
                      if ((c.clubName ?? '').isNotEmpty) c.clubName!,
                      if ((c.branch ?? '').isNotEmpty) c.branch!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(
                        11.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
          if (c.isInjured)
            PremiumStatusChip(
                label: 'Sakat',
                color: const Color(0xFFF43F5E),
                icon: Icons.personal_injury_rounded),
        ]),
        const SizedBox(height: 14),
        Divider(color: line, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          _stat(ink, 'Devam', '%${c.attendanceRate}',
              alert: c.attendanceRate < 60),
          _stat(ink, 'Borç',
              c.hasDebt ? '${c.openFeeTotal.round()} ₺' : 'Yok',
              alert: c.hasDebt),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    c.nextEventAt == null
                        ? '—'
                        : '${c.nextEventAt!.day}.${c.nextEventAt!.month} '
                            '${c.nextEventAt!.hour.toString().padLeft(2, '0')}:'
                            '${c.nextEventAt!.minute.toString().padLeft(2, '0')}',
                    style: jakarta(13, FontWeight.w800, ink)),
                const SizedBox(height: 2),
                Text(c.nextEvent ?? 'Program yok',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(
                        10.5, FontWeight.w600, SwanColors.textSecondary)),
              ],
            ),
          ),
        ]),
        if (c.hasDebt) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/aidatlarim'),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${c.openFeeCount} ödenmemiş aidat · öde',
                  style: jakarta(12.5, FontWeight.w800, kTeal)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _stat(Color ink, String label, String value, {bool alert = false}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: jakarta(13, FontWeight.w800,
                    alert ? const Color(0xFFF43F5E) : ink)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    jakarta(10.5, FontWeight.w600, SwanColors.textSecondary)),
          ],
        ),
      );

  Widget _linkCta(
      BuildContext context, bool isDark, String title, String subtitle) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/veli-bagla'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4FC3F7), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: .3),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.family_restroom_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sora(16, FontWeight.w800, Colors.white)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: jakarta(11.5, FontWeight.w600, Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white, size: 22),
        ]),
      ),
    );
  }

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

  Widget _skeleton(Color surf, Color line, double h) => Container(
        height: h,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: kTeal, strokeWidth: 2)),
      );

  Widget _label(String t) => Padding(
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
              Text(place,
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

  String _kindLabel(String kind) => switch (kind) {
        'match' => 'Maç',
        'training' => 'Antrenman',
        'meeting' => 'Toplantı',
        _ => 'Etkinlik',
      };
}

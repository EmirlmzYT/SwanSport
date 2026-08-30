import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/premium.dart';
import '../../../athlete_workspace/presentation/screens/athlete_home_screen.dart';
import '../../../demo/demo_role.dart';
import '../../../home/presentation/screens/guardian_home_screen.dart';
import '../../../home/presentation/screens/member_home_screen.dart';
import '../../../verification/presentation/club_pending_screen.dart';

/// Antrenör Paneli — Supabase verisine bağlı, premium tasarım (v3).
class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final demoRole = ref.watch(demoRoleProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;

    // Rol henüz yüklenmediyse bekle — yanlış ekranı gösterip anında
    // değiştirmek (ekran titremesi) yerine sakin bir yükleme göster.
    if (demoRole == null && profileAsync.isLoading) {
      return Scaffold(backgroundColor: bg, body: premiumLoading());
    }

    // Role göre ana ekran — yönetim paneli yalnızca antrenör/yöneticiye.
    // Demo rolü varsa onu, yoksa gerçek üyelik rolünü esas al.
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

    // Kulüp onay bekliyorsa panel kilitli — inceleme ekranını göster.
    // Demo rolü aktifken kilidi atla ki roller gezilebilsin.
    if (demoRole == null && club != null && club.isPending) {
      return const ClubPendingScreen();
    }
    final athletes = ref.watch(clubAthletesProvider);
    final events = ref.watch(eventsProvider);

    final clubName = club?.name ?? 'SwanSport';
    final demoLabel = ref.watch(effectiveRoleLabelProvider);
    final role = demoLabel ??
        (profile?.role != null ? _roleLabel(profile!.role!) : 'Üye');

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
                await ref.read(clubAthletesProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
                children: [
                  // Üst bar
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kTeal, kTealDeep],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          clubName.isNotEmpty ? clubName[0].toUpperCase() : 'S',
                          style: sora(17, FontWeight.w800, Colors.white),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clubName,
                                style: jakarta(14, FontWeight.w800, ink)),
                            Text(role,
                                style: jakarta(11, FontWeight.w600,
                                    SwanColors.textSecondary)),
                          ],
                        ),
                      ),
                      const InboxActions(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(_today(),
                      style: jakarta(
                          11, FontWeight.w700, SwanColors.textSecondary,
                          ls: 1.4)),
                  const SizedBox(height: 5),
                  Text('İyi çalışmalar,',
                      style: sora(25, FontWeight.w800, ink)),
                  Text(profile?.firstName ?? 'Antrenör',
                      style: sora(25, FontWeight.w800, ink)),
                  const SizedBox(height: 18),
                  // Yaklaşan etkinlik hero
                  events.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      final now = DateTime.now();
                      final upcoming = list
                          .where((e) => e.startsAt
                              .isAfter(now.subtract(const Duration(hours: 3))))
                          .toList();
                      if (upcoming.isEmpty) return _noEvent(context, isDark);
                      return _hero(
                          context, upcoming.first, athletes.valueOrNull);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Metrikler
                  Row(
                    children: [
                      _tile(
                        isDark,
                        icon: Icons.groups_rounded,
                        iconBg: const Color(0xFFE3F7EF),
                        iconFg: const Color(0xFF10B981),
                        value: athletes.maybeWhen(
                            data: (a) => '${a.length}', orElse: () => '—'),
                        label: 'Aktif sporcu',
                      ),
                      const SizedBox(width: 11),
                      _tile(
                        isDark,
                        icon: Icons.event_rounded,
                        iconBg: const Color(0xFFE5EEFE),
                        iconFg: const Color(0xFF3B82F6),
                        value: events.maybeWhen(
                            data: (e) => '${e.length}', orElse: () => '—'),
                        label: 'Etkinlik',
                      ),
                    ],
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
        onAction: () => Navigator.pushNamed(context, '/attendance'),
      ),
    );
  }

  Widget _hero(BuildContext context, EventRow e, List<AthleteRow>? athletes) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment.topRight,
          radius: 1.3,
          colors: [kTealBright, kTeal, kTealDeep],
          stops: [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: kTeal.withValues(alpha: 0.34),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(
                  'YAKLAŞAN · ${e.kindLabel.toUpperCase()} · ${_hm(e.startsAt)}',
                  style: jakarta(
                      9.5, FontWeight.w700, Colors.white.withValues(alpha: 0.9),
                      ls: 1.0)),
            ],
          ),
          const SizedBox(height: 10),
          Text(e.title, style: sora(19, FontWeight.w800, Colors.white)),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.place_rounded,
                  size: 14, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(e.place ?? '—',
                    style: jakarta(12, FontWeight.w500,
                        Colors.white.withValues(alpha: 0.92))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (athletes != null && athletes.isNotEmpty) _faces(athletes),
              const Spacer(),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pushNamed(context, '/attendance'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.checklist_rounded,
                            size: 15, color: kTealDeep),
                        const SizedBox(width: 7),
                        Text('Yoklama',
                            style: jakarta(12.5, FontWeight.w800, kTealDeep)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _faces(List<AthleteRow> athletes) {
    final show = athletes.take(3).toList();
    final extra = athletes.length - show.length;
    const step = 18.0;
    return SizedBox(
      height: 27,
      width: step * show.length + (27 - step) + (extra > 0 ? 27 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < show.length; i++)
            Positioned(
              left: i * step,
              child: _face(show[i].initials,
                  kAvatarGradients[i % kAvatarGradients.length]),
            ),
          if (extra > 0)
            Positioned(
              left: show.length * step,
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0A8F97), width: 2),
                ),
                alignment: Alignment.center,
                child: Text('+$extra',
                    style: sora(8.5, FontWeight.w700, Colors.white, ls: 0)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _face(String initials, List<Color> grad) => Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0A8F97), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(initials, style: sora(9, FontWeight.w700, Colors.white)),
      );

  Widget _noEvent(BuildContext context, bool isDark) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: kTeal, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yaklaşan etkinlik yok',
                    style: jakarta(13.5, FontWeight.w700, ink)),
                Text('Takvimden antrenman/maç ekle.',
                    style: jakarta(
                        11.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/calendar'),
            child: const Icon(Icons.add_circle_rounded, color: kTeal, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    bool isDark, {
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String value,
    required String label,
  }) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: iconFg),
            ),
            const SizedBox(height: 9),
            Text(value, style: sora(22, FontWeight.w800, ink)),
            const SizedBox(height: 1),
            Text(label,
                style:
                    jakarta(10.5, FontWeight.w600, SwanColors.textSecondary)),
          ],
        ),
      ),
    );
  }


  String _roleLabel(String role) => switch (role) {
        'club_admin' => 'Yönetici',
        'coach' => 'Antrenör',
        'athlete' => 'Sporcu',
        'parent' => 'Veli',
        'official' => 'Görevli',
        _ => 'Üye',
      };

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _today() {
    const days = [
      'PAZARTESİ',
      'SALI',
      'ÇARŞAMBA',
      'PERŞEMBE',
      'CUMA',
      'CUMARTESİ',
      'PAZAR'
    ];
    const months = [
      'OCAK',
      'ŞUBAT',
      'MART',
      'NİSAN',
      'MAYIS',
      'HAZİRAN',
      'TEMMUZ',
      'AĞUSTOS',
      'EYLÜL',
      'EKİM',
      'KASIM',
      'ARALIK'
    ];
    final n = DateTime.now();
    return '${n.day} ${months[n.month - 1]} · ${days[n.weekday - 1]}';
  }
}

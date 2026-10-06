import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/stitch_components.dart';
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

    final clubName = club?.name ?? 'Marmara Okçuluk SK';
    final demoLabel = ref.watch(effectiveRoleLabelProvider);
    final role = demoLabel ??
        (profile?.role != null ? _roleLabel(profile!.role!) : 'Antrenör');

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                children: [
                  // Üst Bar & Inbox
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00666D),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$role olarak',
                                  style: SwanType.caption(
                                    c.ink,
                                    w: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const InboxActions(),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Başlık & Tarih
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operasyon & Kontrol',
                            style: SwanType.h1(c.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _today(),
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                      Text(
                        clubName,
                        style: SwanType.caption(
                          const Color(0xFF00666D),
                          w: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3-Column Compact Metric Band
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.line),
                    ),
                    child: Row(
                      children: [
                        _buildMetricBox(
                          c,
                          'Aktif Sporcu',
                          athletes.maybeWhen(
                            data: (a) => '${a.length}',
                            orElse: () => '—',
                          ),
                          null,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricBox(
                          c,
                          'Katılım Oranı',
                          '%92',
                          Icons.trending_up,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricBox(
                          c,
                          'Açık Seans',
                          events.maybeWhen(
                            data: (e) => '${e.length}',
                            orElse: () => '—',
                          ),
                          null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Canlı Durum Kartı (Hero Card)
                  events.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      final now = DateTime.now();
                      final upcoming = list
                          .where(
                            (e) => e.startsAt.isAfter(
                              now.subtract(const Duration(hours: 3)),
                            ),
                          )
                          .toList();
                      if (upcoming.isEmpty) {
                        return _buildNoEventCard(context, c);
                      }
                      return _buildLiveHeroCard(
                        context,
                        c,
                        upcoming.first,
                        athletes.valueOrNull,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Günün Seans Akışı
                  StitchSectionTitle(
                    title: 'Günün Seans Akışı',
                    actionLabel: 'Tüm Takvim',
                    onAction: () => Navigator.pushNamed(context, '/calendar'),
                  ),
                  const SizedBox(height: 10),
                  events.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      if (list.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.line),
                          ),
                          child: Center(
                            child: Text(
                              'Bugün planlı seans bulunmuyor.',
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: list
                            .take(3)
                            .map((e) => _buildSessionTimelineItem(c, e))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Eylem Bekleyen Operasyonel Görevler (Task Queue)
                  StitchSectionTitle(
                    title: 'Eylem Bekleyen Görevler',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBA1A1A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '3 Bekleyen',
                        style: SwanType.caption(
                          const Color(0xFFBA1A1A),
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTaskTile(
                    c,
                    title: 'Sağlık Kısıtı Onayı',
                    subtitle: '2 sporcu için yeni sağlık belgesi yüklendi',
                    icon: Icons.health_and_safety_outlined,
                    actionLabel: 'İncele',
                    onTap: () => Navigator.pushNamed(context, '/medical'),
                  ),
                  const SizedBox(height: 8),
                  _buildTaskTile(
                    c,
                    title: 'Veli İzin Formları',
                    subtitle: 'Gelecek turnuva için 4 onay bekleniyor',
                    icon: Icons.verified_user_outlined,
                    actionLabel: 'Takip Et',
                    onTap: () => Navigator.pushNamed(context, '/documents'),
                  ),
                  const SizedBox(height: 8),
                  _buildTaskTile(
                    c,
                    title: 'Eksik Yoklama Kayıtları',
                    subtitle: 'Dün tamamlanan akşam seansı onayı',
                    icon: Icons.fact_check_outlined,
                    actionLabel: 'Kaydet',
                    onTap: () => Navigator.pushNamed(context, '/attendance'),
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

  Widget _buildMetricBox(
    SwanPalette c,
    String label,
    String value,
    IconData? icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: SwanType.caption(c.inkMuted)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: SwanType.h2(
                    icon != null ? const Color(0xFF00666D) : c.ink,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  Icon(icon, size: 16, color: const Color(0xFF00666D)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveHeroCard(
    BuildContext context,
    SwanPalette c,
    EventRow event,
    List<AthleteRow>? athletes,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF00666D),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00666D).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8CF2FC),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'CANLI SEANS',
                      style: SwanType.caption(
                        const Color(0xFF8CF2FC),
                        w: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                event.place ?? 'Hedef Blokları',
                style: SwanType.caption(
                  Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: SwanType.h2(Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${_hm(event.startsAt)} - ${_hm(event.endsAt ?? event.startsAt.add(const Duration(hours: 2)))}',
            style: SwanType.caption(
              Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mevcut Katılım',
                      style: SwanType.caption(Colors.white),
                    ),
                    Text(
                      '${athletes?.length ?? 16} Sporcu Kayıtlı',
                      style: SwanType.caption(
                        Colors.white,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.85,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF8CF2FC),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00666D),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Canlı Yoklamaya Git',
                    style: SwanType.bodySm(
                      const Color(0xFF00666D),
                      w: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEventCard(BuildContext context, SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00666D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Color(0xFF00666D),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktif Seans Yok',
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
                Text(
                  'Takvim üzerinden yeni antrenman seansı başlatın.',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
            icon: const Icon(
              Icons.add_circle,
              color: Color(0xFF00666D),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTimelineItem(SwanPalette c, EventRow event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _hm(event.startsAt),
                  style: SwanType.caption(
                    const Color(0xFF00666D),
                    w: FontWeight.w800,
                  ),
                ),
                Text(
                  _hm(event.endsAt ??
                      event.startsAt.add(const Duration(hours: 2))),
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.title,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00666D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Planlı',
                        style: SwanType.caption(
                          const Color(0xFF00666D),
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  event.place ?? 'Kulüp Poligonu',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(
    SwanPalette c, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF00666D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF00666D), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: SwanType.caption(c.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionLabel,
                style: SwanType.caption(
                  const Color(0xFF00666D),
                  w: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    final n = DateTime.now();
    return '${n.day} ${months[n.month - 1]} ${n.year} • ${days[n.weekday - 1]}';
  }
}

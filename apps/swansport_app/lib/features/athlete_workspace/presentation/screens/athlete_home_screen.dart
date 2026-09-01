import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/summary_section.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

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
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final events = ref.watch(eventsProvider);
    final anns = ref.watch(announcementsProvider);
    final fees = ref.watch(myFeesProvider);
    final docs = ref.watch(vaultDocsProvider);
    final teams = ref.watch(teamsProvider);
    final injuries = ref.watch(injuriesProvider);
    // Kendi sporcu kaydım — sağlık ve performans satırlarını buna göre
    // süzüyorum; ikisi de kulüp geneli döndürüyor.
    final myAthlete = profile == null
        ? null
        : ref.watch(athleteByProfileProvider(profile.id)).valueOrNull;

    // Sporcunun kendi kartı — katılım, hedef ve başarı sayıları.
    final card = myAthlete == null
        ? const AsyncValue<AthleteCard>.data(AthleteCard.empty)
        : ref.watch(athleteCardProvider(myAthlete.id));

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
                              style: SwanType.bodySm(ink, w: FontWeight.w800)),
                          Text(
                              club?.name != null ? 'Sporcu · ${club!.name}' : 'Sporcu',
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const InboxActions(),
                  ]),
                  const SizedBox(height: 18),

                  Text(_todayLabel().toUpperCase(),
                      style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Merhaba, $name',
                      style: SwanType.h2(ink)),
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

                  // Brief §10: her bölüm kısa özet + "Tümünü gör".
                  // Eskiden burada dört düğmelik bir kısayol ızgarası vardı;
                  // düğmeler hiçbir şey söylemiyordu — "Belgelerim" yazıyordu
                  // ama belgen eksik mi tam mı, girmeden anlaşılmıyordu.

                  // Başlık "Bugün" değil "Program": `eventsProvider` yaklaşan
                  // etkinlikleri döndürüyor, hepsi bugün değil. Gelecek
                  // haftaki maçın üstüne "Bugün" yazmak yanlış bilgi olurdu.
                  SummarySection(
                    title: 'Program',
                    onSeeAll: () => Navigator.pushNamed(context, '/calendar'),
                    child: _sum(events, (list) {
                      final now = DateTime.now();
                      final up = (list
                              .where((e) => e.startsAt.isAfter(
                                  now.subtract(const Duration(hours: 3))))
                              .toList()
                            ..sort((a, b) => a.startsAt.compareTo(b.startsAt)))
                          .skip(1)
                          .take(3)
                          .toList();
                      if (up.isEmpty) {
                        return SummaryLine.empty('Başka etkinlik yok');
                      }
                      return Column(
                          children: up
                              .map((e) => _agenda(isDark, e.startsAt, e.title,
                                  e.place ?? _kindLabel(e.kind)))
                              .toList());
                    }),
                  ),

                  // Gelişim artık **katılımı da** gösteriyor.
                  //
                  // Sporcunun her hafta ürettiği tek veri katılım ve bunu
                  // hiçbir yerde göremiyordu: yoklama alınıyor, kulüp
                  // raporlarına düşüyor, sporcuya geri dönmüyordu. Döngünün
                  // kullanıcıya kapanan ucu eksikti.
                  //
                  // Yeni sorgu yazılmadı: `athlete_card` (0046) bu sayıları
                  // zaten sporcu bazlı ve yetki denetimli döndürüyor.
                  // Kulüp geneli `attendanceSummaryProvider` kullanılamazdı —
                  // sporcuya bütün kadronun katılımını göstermek olurdu.
                  SummarySection(
                    title: 'Gelişim',
                    onSeeAll: () => Navigator.pushNamed(
                        context, '/performance-analytics'),
                    child: _sum(card, (c) {
                      if (!c.hasData) {
                        return SummaryLine.empty('Henüz kayıt yok');
                      }
                      final parts = <String>[
                        if (c.goalsActive > 0) '${c.goalsActive} açık hedef',
                        if (c.goalsDone > 0) '${c.goalsDone} tamamlanan',
                        if (c.achievements > 0) '${c.achievements} başarı',
                      ];
                      return SummaryLine(
                        icon: Icons.trending_up_rounded,
                        text: c.trainings > 0
                            ? '${c.trainings} antrenman · %${c.attendancePct} katılım'
                            : 'Katılım kaydı yok',
                        sub: parts.isEmpty ? null : parts.join(' · '),
                        // %80 sportif bir eşik değil, "düzenli sayılır"
                        // sınırı. Altını kırmızı yapmıyoruz: sporcuyu kendi
                        // ana sayfasında suçlamak işe yaramıyor.
                        tone: c.attendancePct >= 80
                            ? context.swan.success
                            : null,
                      );
                    }),
                  ),

                  SummarySection(
                    title: 'Takımım',
                    onSeeAll: () => Navigator.pushNamed(context, '/teams'),
                    child: _sum(teams, (list) {
                      if (list.isEmpty) return SummaryLine.empty('Takım yok');
                      final t = list.first;
                      return SummaryLine(
                        icon: Icons.groups_rounded,
                        text: t.name,
                        sub: list.length > 1
                            ? '${list.length} takımdasın'
                            : club?.name,
                      );
                    }),
                  ),

                  SummarySection(
                    title: 'Sağlık',
                    onSeeAll: () =>
                        Navigator.pushNamed(context, '/medical-center'),
                    child: _sum(injuries, (list) {
                      final mine = myAthlete == null
                          ? null
                          : list
                              .where((r) => r.athleteId == myAthlete.id)
                              .firstOrNull;
                      // Kayıt yoksa "Sağlam" YAZMIYORUM. Sakatlık listesi
                      // kulüp geneli; sporcuya RLS ile kapalıysa da boş
                      // dönüyor ve ikisi buradan ayırt edilemiyor. Sağlıkla
                      // ilgili bir şeyi veri olmadan iddia etmek yanlış.
                      if (mine == null) {
                        return SummaryLine.empty('Sağlık kaydı yok');
                      }
                      return SummaryLine(
                        icon: Icons.favorite_rounded,
                        text: mine.statusLabel,
                        sub: mine.note,
                        tone: switch (mine.status) {
                          'injured' => context.swan.danger,
                          'pending' => context.swan.warning,
                          _ => context.swan.success,
                        },
                      );
                    }),
                  ),

                  SummarySection(
                    title: 'Belgeler',
                    onSeeAll: () => Navigator.pushNamed(context, '/documents'),
                    child: _sum(docs, (list) {
                      final mine = list
                          .where((d) =>
                              d.ownerId == profile?.id ||
                              (myAthlete != null && d.ownerId == myAthlete.id))
                          .toList();
                      if (mine.isEmpty) {
                        return SummaryLine.empty('Belge yüklenmemiş');
                      }
                      final ok = mine.where((d) => d.verified).length;
                      final missing = mine.length - ok;
                      return SummaryLine(
                        icon: Icons.folder_rounded,
                        text: missing == 0
                            ? '${mine.length} belge onaylı'
                            : '$missing belge onay bekliyor',
                        sub: '${mine.length} belge yüklü',
                        tone: missing == 0
                            ? context.swan.success
                            : context.swan.warning,
                      );
                    }),
                  ),

                  SummarySection(
                    title: 'Finans',
                    onSeeAll: () => Navigator.pushNamed(context, '/aidatlarim'),
                    child: _sum(fees, (list) {
                      final open =
                          list.where((f) => f.status != 'paid').toList();
                      if (open.isEmpty) {
                        return SummaryLine(
                          icon: Icons.check_circle_rounded,
                          text: 'Borcun yok',
                          tone: context.swan.success,
                        );
                      }
                      final total = open.fold<num>(0, (a, f) => a + f.amount);
                      final overdue = open.where((f) => f.overdue).length;
                      return SummaryLine(
                        icon: Icons.receipt_long_rounded,
                        text: money(total),
                        sub: overdue > 0
                            ? '${open.length} ödenmemiş · $overdue gecikmiş'
                            : '${open.length} ödenmemiş',
                        tone: overdue > 0
                            ? context.swan.danger
                            : context.swan.warning,
                      );
                    }),
                  ),

                  SummarySection(
                    title: 'Duyurular',
                    onSeeAll: () =>
                        Navigator.pushNamed(context, '/announcements'),
                    child: _sum(anns, (list) {
                      if (list.isEmpty) return SummaryLine.empty('Duyuru yok');
                      return Column(
                          children: list
                              .take(3)
                              .map((a) =>
                                  _annCard(isDark, a.title, a.body, a.pinned))
                              .toList());
                    }),
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

  /// Bölüm gövdesi — yükleniyor/hata hâlini altı yerde tekrar yazmamak için.
  ///
  /// Hata sessizce yutulmuyor: özet satırı "yüklenemedi" diyor. Boş görünen
  /// bir bölüm ile yüklenememiş bir bölüm kullanıcı için aynı şey değil.
  Widget _sum<T>(AsyncValue<T> v, Widget Function(T) build) => v.when(
        loading: () => const SummaryLine(
            icon: Icons.hourglass_empty_rounded, text: 'Yükleniyor…'),
        error: (_, __) => const SummaryLine(
            icon: Icons.cloud_off_rounded, text: 'Yüklenemedi'),
        data: build,
      );

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
                  style: SwanType.caption(Colors.white, w: FontWeight.w800)),
            ),
            const Spacer(),
            const Icon(Icons.sports_rounded, color: Colors.white, size: 20),
          ]),
          const SizedBox(height: 16),
          Text(e.title, style: SwanType.h2(Colors.white)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text('${_dayLabel(d)} · $hm',
                style: SwanType.caption(Colors.white, w: FontWeight.w600)),
            const SizedBox(width: 14),
            if (e.place != null) ...[
              const Icon(Icons.place_rounded, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(e.place!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(Colors.white, w: FontWeight.w600)),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _heroEmpty(bool isDark, String text) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
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
              Text(text, style: SwanType.bodySm(ink, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Antrenörün program eklediğinde burada görürsün.',
                  style: SwanType.caption(SwanColors.textSecondary)),
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
              Text('${_dayLabel(t)} · $place',
                  style:
                      SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _annCard(bool isDark, String title, String body, bool pinned) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
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
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SwanType.caption(SwanColors.textSecondary)),
        ],
      ),
    );
  }


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

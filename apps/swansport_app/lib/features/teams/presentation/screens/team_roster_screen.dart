import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../communities/presentation/community_chat_screen.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/widgets/swan_tabs.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Takım merkezi — kadro, program ve sohbet tek yerde.
///
/// **Neden tek sayfa:** denetimde takımın "kadro listesi" olduğu, operasyonel
/// bir merkez olmadığı çıktı. Antrenörün bir takım hakkında günlük işleri
/// üç ayrı ekrandaydı: kadro burada, program takvimde, iletişim ise ya
/// herkese açık duyuru ya tek tek DM.
///
/// Rota argümanı: `{'id': takımId, 'name': takımAdı}`.
class TeamRosterScreen extends ConsumerStatefulWidget {
  const TeamRosterScreen({super.key, required this.teamId, required this.teamName});

  final String teamId;
  final String teamName;

  @override
  ConsumerState<TeamRosterScreen> createState() => _TeamRosterScreenState();
}

class _TeamRosterScreenState extends ConsumerState<TeamRosterScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final teamId = widget.teamId;
    final teamName = widget.teamName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final canManage = club != null &&
        (club.role == 'club_admin' || club.role == 'coach');
    // Kanal yoksa (0045 çalıştırılmadı ya da kullanıcı takımın üyesi değil)
    // sohbet sekmesi hiç gösterilmiyor — boş sekme açıp "burada bir şey yok"
    // demek daha kötü.
    final channelId = ref.watch(teamChannelProvider(teamId)).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(children: [
                  Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: ink),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Takım Kadrosu', style: SwanType.h3(ink)),
                          Text(teamName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.h2(ink)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  SwanSegmentedTabs(
                    // Sıra bilinçli: Özet önce, çünkü takım sayfasını açan
                    // kişinin ilk sorusu "ne oluyor". Kadro ve program
                    // ondan sonra, sohbet ve gelişim en sonda.
                    labels: channelId == null
                        ? const ['Özet', 'Program', 'Kadro', 'Gelişim']
                        : const ['Özet', 'Program', 'Kadro', 'Sohbet',
                                 'Gelişim'],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 12),
                ]),
              ),
              Expanded(child: _body(context, isDark, ink, line, canManage,
                  channelId, teamId, teamName)),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  /// Seçili sekmenin gövdesi.
  Widget _body(BuildContext context, bool isDark, Color ink, Color line,
      bool canManage, String? channelId, String teamId, String teamName) {
    // Sekme sırası kanal varlığına göre kayıyor; indeks yerine ada
    // bakmak, kanal yokken yanlış sekmeyi açmayı imkânsız kılıyor.
    final labels = channelId == null
        ? const ['Özet', 'Program', 'Kadro', 'Gelişim']
        : const ['Özet', 'Program', 'Kadro', 'Sohbet', 'Gelişim'];
    final name = labels[_tab.clamp(0, labels.length - 1)];

    switch (name) {
      case 'Program':
        return _schedule(context, isDark, ink, line, teamId);
      case 'Kadro':
        return _rosterTab(context, isDark, ink, canManage, teamId);
      case 'Sohbet':
        // Sohbet kendi kaydırmasını yönetiyor; liste içine gömülmüyor.
        return CommunityChatScreen(communityId: channelId!, title: teamName);
      case 'Gelişim':
        return _growth(context, isDark, ink, line, teamId);
      default:
        return _overview(context, isDark, ink, line, teamId, teamName);
    }
  }

  /// Özet — "bu takımda ne oluyor" sorusunun tek ekranlık cevabı.
  ///
  /// Yeni sorgu yok: yaklaşan etkinlik, kadro sayısı ve duyurular zaten
  /// çekiliyordu, yalnızca bir arada gösterilmiyordu.
  Widget _overview(BuildContext context, bool isDark, Color ink, Color line,
      String teamId, String teamName) {
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final events = ref.watch(eventsProvider).valueOrNull ?? const <EventRow>[];
    final roster = ref.watch(teamRosterProvider(teamId)).valueOrNull ?? const [];
    final anns = ref.watch(announcementsProvider).valueOrNull ?? const [];

    final now = DateTime.now();
    final upcoming = events
        .where((e) => e.teamId == teamId && e.startsAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
      children: [
        if (upcoming.isEmpty && roster.isEmpty && anns.isEmpty)
          premiumEmpty(
            context,
            icon: Icons.groups_rounded,
            title: 'Takım yeni',
            subtitle: 'Kadro eklenip antrenman oluşturulunca burada '
                'özetini göreceksin.',
          )
        else ...[
          if (upcoming.isNotEmpty) ...[
            Text('Sıradaki', style: SwanType.h3(ink)),
            const SizedBox(height: 8),
            _eventTile(isDark, ink, line, upcoming.first),
            const SizedBox(height: 18),
          ],

          Row(children: [
            Expanded(
              child: _statBox(c, '${roster.length}', 'sporcu'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statBox(
                  c, '${upcoming.length}', 'yaklaşan etkinlik'),
            ),
          ]),

          if (anns.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Duyurular', style: SwanType.h3(ink)),
            const SizedBox(height: 8),
            for (final a in anns.take(2))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(ink, w: FontWeight.w700)),
                    if (a.body.isNotEmpty)
                      Text(a.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.caption(c.inkMuted)),
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }

  /// Gelişim — takımın sporcularının ölçüm ve hedef durumu.
  ///
  /// Kulüp geneli `performanceOverviewProvider` takımın sporcularına
  /// süzülüyor. Sporcuya özel `athlete_card` burada kullanılamazdı: her
  /// sporcu için ayrı çağrı, kadro kadar gidiş-dönüş demekti.
  Widget _growth(BuildContext context, bool isDark, Color ink, Color line,
      String teamId) {
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final roster = ref.watch(teamRosterProvider(teamId)).valueOrNull ?? const [];
    final perf = ref.watch(performanceOverviewProvider);

    return perf.when(
      loading: premiumLoading,
      error: (e, _) => premiumError(context, '$e'),
      data: (all) {
        final ids = roster.map((m) => m.athleteId).toSet();
        final mine = all.where((r) => ids.contains(r.athleteId)).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));

        if (mine.isEmpty) {
          return premiumEmpty(
            context,
            icon: Icons.trending_up_rounded,
            title: 'Gelişim kaydı yok',
            subtitle: 'Ölçüm girildikçe ve hedef konuldukça burada '
                'takımın gelişimi görünecek.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
          itemCount: mine.length,
          itemBuilder: (_, i) {
            final r = mine[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.bodySm(ink, w: FontWeight.w700)),
                      Text('${r.tests} ölçüm · ${r.goals} hedef',
                          style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ),
                Text('%${r.progress}',
                    style: SwanType.bodySm(
                        r.progress >= 50 ? c.success : c.inkMuted,
                        w: FontWeight.w800)),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _statBox(SwanPalette c, String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: SwanType.h3(c.ink)),
          Text(label, style: SwanType.caption(c.inkMuted)),
        ]),
      );

  Widget _rosterTab(BuildContext context, bool isDark, Color ink,
      bool canManage, String teamId) {
    final roster = ref.watch(teamRosterProvider(teamId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teamRosterProvider(teamId));
        await ref.read(teamRosterProvider(teamId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
        children: [
                  roster.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.groups_rounded,
                          title: 'Kadro boş',
                          subtitle: canManage
                              ? 'Aşağıdan kulüp sporcularını takıma ekle.'
                              : 'Bu takıma henüz sporcu eklenmemiş.',
                        );
                      }
                      return Column(
                          children: list
                              .map((m) => _member(context, ref, isDark, m,
                                  canManage))
                              .toList());
                    },
                  ),

                  if (canManage) ...[
                    const SizedBox(height: 22),
                    Text('Kulüp Sporcuları', style: SwanType.h3(ink)),
                    const SizedBox(height: 6),
                    Text('Takıma eklemek için dokun.',
                        style: SwanType.caption(SwanColors.textSecondary)),
                    const SizedBox(height: 10),
                    _available(context, ref, isDark, roster.valueOrNull),
                  ],
        ],
      ),
    );
  }

  /// Takımın programı — bu takıma bağlı etkinlikler.
  ///
  /// `EventRow.teamId` 0045'te modele eklendi; şemada zaten vardı ama
  /// okunmuyordu, bu yüzden "bu takımın programı" gösterilemiyordu.
  Widget _schedule(BuildContext context, bool isDark, Color ink, Color line,
      String teamId) {
    final events = ref.watch(eventsProvider);
    return events.when(
      loading: premiumLoading,
      error: (e, _) => premiumError(context, '$e'),
      data: (all) {
        final mine = all.where((e) => e.teamId == teamId).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        if (mine.isEmpty) {
          return premiumEmpty(
            context,
            icon: Icons.event_note_rounded,
            title: 'Program boş',
            subtitle: 'Bu takıma bağlı yaklaşan etkinlik yok.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
          itemCount: mine.length,
          itemBuilder: (_, i) => _eventTile(isDark, ink, line, mine[i]),
        );
      },
    );
  }

  Widget _eventTile(bool isDark, Color ink, Color line, EventRow e) {
    final c = isDark ? SwanPalette.dark : SwanPalette.light;
    final hh = e.startsAt.hour.toString().padLeft(2, '0');
    final mm = e.startsAt.minute.toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$hh:$mm', style: SwanType.bodySm(ink, w: FontWeight.w800)),
          Text('${e.startsAt.day}.${e.startsAt.month}',
              style: SwanType.caption(c.inkMuted)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.bodySm(ink, w: FontWeight.w700)),
            Text(e.place ?? e.kindLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.caption(c.inkMuted)),
          ]),
        ),
      ]),
    );
  }

  Widget _member(
      BuildContext context,
      WidgetRef ref,
      bool isDark,
      ({String id, String athleteId, String name, String? jersey}) m,
      bool canManage) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        GradientAvatar(
            initials: m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
            size: 40,
            gradientIndex: m.name.length % 4),
        const SizedBox(width: 12),
        Expanded(
          child: Text(m.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SwanType.bodySm(ink, w: FontWeight.w700)),
        ),
        if (m.jersey != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child:
                Text('#${m.jersey}', style: SwanType.caption(kTeal, w: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
        ],
        if (canManage)
          GestureDetector(
            onTap: () async {
              await ref.read(clubDataServiceProvider).removeFromTeam(m.id);
              ref.invalidate(teamRosterProvider(widget.teamId));
            },
            child: Icon(Icons.remove_circle_outline_rounded,
                size: 20, color: SwanColors.textSecondary),
          ),
      ]),
    );
  }

  /// Takımda olmayan kulüp sporcuları.
  Widget _available(
      BuildContext context,
      WidgetRef ref,
      bool isDark,
      List<({String id, String athleteId, String name, String? jersey})>?
          roster) {
    final athletes = ref.watch(clubAthletesProvider).valueOrNull ?? const [];
    final inTeam = (roster ?? const []).map((m) => m.athleteId).toSet();
    final free = athletes.where((a) => !inTeam.contains(a.id)).toList();

    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    if (free.isEmpty) {
      return Text('Kulüpteki tüm sporcular bu takımda.',
          style: SwanType.caption(SwanColors.textSecondary));
    }

    return Column(
      children: free.map((a) {
        return GestureDetector(
          onTap: () async {
            try {
              await ref
                  .read(clubDataServiceProvider)
                  .addToTeam(widget.teamId, a.id);
              ref.invalidate(teamRosterProvider(widget.teamId));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Eklenemedi: $e'),
                    backgroundColor: SwanPalette.light.danger));
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: line),
            ),
            child: Row(children: [
              GradientAvatar(
                  initials: a.initials,
                  size: 34,
                  gradientIndex: a.fullName.length % 4),
              const SizedBox(width: 11),
              Expanded(
                child: Text(a.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(ink, w: FontWeight.w600)),
              ),
              const Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: kTeal),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

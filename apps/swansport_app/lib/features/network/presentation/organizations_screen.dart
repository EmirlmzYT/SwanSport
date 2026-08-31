import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';

/// Lig / turnuva / kupa organizasyonları.
///
/// Puan kuralı organizasyonun kendi ayarından gelir — hiçbir branş
/// sabitlenmiyor. Voleybolda 3-2-1-0, futbolda 3-1-0 kurulabilir.
class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  ConsumerState<OrganizationsScreen> createState() =>
      _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final async = ref.watch(organizationsProvider(''));

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
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(children: [
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
                  Text('Organizasyonlar',
                      style: SwanType.h2(ink)),
                  const Spacer(),
                  AddButton(onTap: _create, tooltip: 'Organizasyon aç'),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(organizationsProvider(''));
                    await ref.read(organizationsProvider('').future);
                  },
                  child: async.when(
                    loading: () => ListView(children: [premiumLoading()]),
                    error: (e, _) =>
                        ListView(children: [premiumError(context, '$e')]),
                    data: (list) => list.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.only(top: 40),
                            children: [
                              premiumEmpty(
                                context,
                                icon: Icons.emoji_events_rounded,
                                title: 'Organizasyon yok',
                                subtitle:
                                    'Lig, turnuva ve kupalar burada görünür. '
                                    'Kulübünle bir organizasyon açabilirsin.',
                                actionLabel: 'Organizasyon aç',
                                onAction: _create,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 132),
                            itemCount: list.length,
                            itemBuilder: (_, i) =>
                                _card(isDark, ink, list[i]),
                          ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _card(bool isDark, Color ink, Organization o) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return GestureDetector(
      onTap: () => _openDetail(o),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE9B949).withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                size: 21, color: Color(0xFFD9860B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(ink, w: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    [
                      o.kindLabel,
                      if ((o.sportName ?? '').isNotEmpty) o.sportName!,
                      if ((o.ageGroup ?? '').isNotEmpty) o.ageGroup!,
                      if ((o.cityName ?? '').isNotEmpty) o.cityName!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${o.participantCount} takım',
                    style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          if (o.isFinished)
            PremiumStatusChip(
                label: 'Bitti',
                color: SwanColors.textSecondary,
                icon: Icons.flag_rounded)
          else
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }

  // ------------------------------- detay -----------------------------------
  Future<void> _openDetail(Organization o) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    var tab = 0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: surf,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(children: [
            Text(o.name, style: SwanType.h3(ink)),
            const SizedBox(height: 3),
            Text('${o.kindLabel} · ${o.participantCount} takım',
                style:
                    SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(children: [
              for (final t in const [(0, 'Puan durumu'), (1, 'Fikstür')])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheet(() => tab = t.$1),
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.only(right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tab == t.$1 ? kTeal : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: tab == t.$1 ? kTeal : line),
                      ),
                      child: Text(t.$2,
                          style: SwanType.caption(tab == t.$1 ? Colors.white : ink, w: FontWeight.w800)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: tab == 0
                  ? _standings(o, ink, line)
                  : _fixture(o, ink, line),
            ),
            if (o.canManage) ...[
              Divider(color: line, height: 16),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _addParticipant(o);
                    },
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: line),
                      ),
                      child: Text('Takım ekle',
                          style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _generate(o);
                    },
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [kTealBright, kTeal]),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text('Fikstür oluştur',
                          style:
                              SwanType.caption(Colors.white, w: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
            ],
          ]),
        );
      }),
    );
  }

  Widget _standings(Organization o, Color ink, Color line) {
    return Consumer(builder: (_, r, __) {
      final s = r.watch(standingsProvider(o.id));
      return s.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Text('Katılımcı yok',
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)))
            : ListView(children: [
                Row(children: [
                  const SizedBox(width: 26),
                  Expanded(
                      child: Text('Takım', style: SwanType.h3(ink))),
                  for (final h in const ['O', 'G', 'B', 'M', 'AV', 'P'])
                    SizedBox(
                      width: h == 'P' ? 30 : 24,
                      child: Text(h,
                          textAlign: TextAlign.center,
                          style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
                    ),
                ]),
                Divider(color: line, height: 12),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(children: [
                      SizedBox(
                        width: 26,
                        child: Text('${i + 1}',
                            style: SwanType.caption(i == 0 ? kTeal : SwanColors.textSecondary, w: FontWeight.w800)),
                      ),
                      Expanded(
                        child: Text(rows[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.caption(ink, w: FontWeight.w700)),
                      ),
                      for (final v in [
                        rows[i].played,
                        rows[i].won,
                        rows[i].drawn,
                        rows[i].lost,
                        rows[i].diff,
                      ])
                        SizedBox(
                          width: 24,
                          child: Text('$v',
                              textAlign: TextAlign.center,
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                        ),
                      SizedBox(
                        width: 30,
                        child: Text('${rows[i].points}',
                            textAlign: TextAlign.center,
                            style: SwanType.caption(kTeal, w: FontWeight.w800)),
                      ),
                    ]),
                  ),
              ]),
      );
    });
  }

  Widget _fixture(Organization o, Color ink, Color line) {
    return Consumer(builder: (_, r, __) {
      final f = r.watch(fixtureProvider(o.id));
      return f.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Text(
                    o.canManage
                        ? 'Fikstür henüz oluşturulmadı'
                        : 'Fikstür yayımlanmadı',
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)))
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final m = rows[i];
                  final showRound =
                      i == 0 || rows[i - 1].round != m.round;
                  return Column(children: [
                    if (showRound)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                        child: Row(children: [
                          Text('${m.round}. HAFTA',
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Expanded(child: Divider(color: line, height: 1)),
                        ]),
                      ),
                    GestureDetector(
                      onTap: m.canManage ? () => _setResult(o, m) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 7),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Text(m.homeName ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: SwanType.caption(ink, w: FontWeight.w700)),
                          ),
                          Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: m.isPlayed
                                  ? kTeal.withValues(alpha: .12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                m.isPlayed
                                    ? '${m.homeScore} - ${m.awayScore}'
                                    : (m.startsAt == null
                                        ? 'vs'
                                        : '${m.startsAt!.day}.${m.startsAt!.month}'),
                                style: SwanType.caption(m.isPlayed
                                        ? kTeal
                                        : SwanColors.textSecondary, w: FontWeight.w800)),
                          ),
                          Expanded(
                            child: Text(m.awayName ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SwanType.caption(ink, w: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  ]);
                },
              ),
      );
    });
  }

  // ------------------------------- eylemler --------------------------------
  Future<void> _create() async {
    final club = ref.read(activeClubProvider).valueOrNull;
    final name = FormField_('Ad', hint: 'Konya Gençler Ligi');
    final age = FormField_('Kategori', hint: 'U-16', required: false);
    final win = FormField_('Galibiyet puanı', hint: '3', required: false);
    final draw = FormField_('Beraberlik puanı', hint: '1', required: false);

    final ok = await showQuickForm(
      context,
      title: 'Organizasyon aç',
      note: 'Puan kuralını branşına göre ayarla.',
      fields: [name, age, win, draw],
      onSubmit: () => ref.read(networkServiceProvider).createOrganization(
            name: name.value,
            clubId: club?.id,
            ageGroup: age.value,
            winPoints: int.tryParse(win.value) ?? 3,
            drawPoints: int.tryParse(draw.value) ?? 1,
          ),
    );
    if (ok == true) ref.invalidate(organizationsProvider(''));
  }

  Future<void> _addParticipant(Organization o) async {
    final club = ref.read(activeClubProvider).valueOrNull;
    final name = FormField_('Takım adı', hint: 'Rakip Kulüp U-16');

    final ok = await showQuickForm(
      context,
      title: 'Takım ekle',
      note: 'Kendi kulübünü eklemek için adını boş bırakabilirsin.',
      fields: [name],
      onSubmit: () => ref.read(networkServiceProvider).joinOrganization(
            o.id,
            clubId: name.value.trim().isEmpty ? club?.id : null,
            name: name.value,
          ),
    );
    if (ok == true) {
      ref.invalidate(standingsProvider(o.id));
      ref.invalidate(organizationsProvider(''));
    }
  }

  Future<void> _generate(Organization o) async {
    try {
      final n = await ref.read(networkServiceProvider).generateFixture(o.id);
      ref.invalidate(fixtureProvider(o.id));
      ref.invalidate(standingsProvider(o.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$n maç oluşturuldu'), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Fikstür oluşturulamadı: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  Future<void> _setResult(Organization o, FixtureRow m) async {
    final home = FormField_('${m.homeName ?? "Ev"} skoru', hint: '3');
    final away = FormField_('${m.awayName ?? "Deplasman"} skoru', hint: '1');

    final ok = await showQuickForm(
      context,
      title: 'Maç sonucu',
      fields: [home, away],
      onSubmit: () => ref.read(networkServiceProvider).setMatchResult(
            m.id,
            int.tryParse(home.value) ?? 0,
            int.tryParse(away.value) ?? 0,
          ),
    );
    if (ok == true) {
      ref.invalidate(fixtureProvider(o.id));
      ref.invalidate(standingsProvider(o.id));
    }
  }
}

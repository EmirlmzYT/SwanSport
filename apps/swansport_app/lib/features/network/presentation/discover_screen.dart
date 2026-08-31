import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Keşfet — kulüpleri il, ilçe, branş ve doğrulanmışlık filtreleriyle bul.
///
/// Kulüp künyesindeki veriler zaten duruyordu; buraya kadar hiçbir yerden
/// filtrelenemiyordu. Ağın dışarıdan ilk temas noktası bu ekran.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  var _filter = const DiscoverFilter();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final async = ref.watch(discoverClubsProvider(_filter));

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
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
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
                  Text('Kulüpleri Keşfet',
                      style: sora(21, FontWeight.w800, ink)),
                ]),
              ),

              // Arama
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: TextField(
                  controller: _search,
                  onChanged: (v) =>
                      setState(() => _filter = _filter.copyWith(query: v.trim())),
                  style: jakarta(13.5, FontWeight.w500, ink),
                  decoration: InputDecoration(
                    hintText: 'Kulüp adı ara…',
                    hintStyle:
                        jakarta(13, FontWeight.w500, SwanColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    filled: true,
                    fillColor: surf,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: line)),
                  ),
                ),
              ),

              _filterBar(isDark, ink),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(discoverClubsProvider(_filter));
                    await ref.read(discoverClubsProvider(_filter).future);
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
                                icon: Icons.travel_explore_rounded,
                                title: 'Kulüp bulunamadı',
                                subtitle: _filter.isEmpty
                                    ? 'Henüz kayıtlı kulüp yok.'
                                    : 'Filtreleri gevşetmeyi dene.',
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

  /// Filtre şeridi. Yalnızca kulüp bulunan il ve branşlar listelenir —
  /// sonucu boş çıkacak bir filtreyi kullanıcıya sunmak zaman kaybı.
  Widget _filterBar(bool isDark, Color ink) {
    final opts = ref.watch(filterOptionsProvider).valueOrNull ?? const [];
    final cities = opts.where((o) => o.kind == 'city').toList();
    final sports = opts.where((o) => o.kind == 'sport').toList();

    Widget chip(String label, bool active, VoidCallback onTap,
        {IconData? icon}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? kTeal
                : (isDark ? const Color(0xFF1A2537) : Colors.white),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: active
                    ? kTeal
                    : (isDark
                        ? const Color(0xFF233149)
                        : const Color(0xFFEAEEF3))),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: active ? Colors.white : ink),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: jakarta(
                    12, FontWeight.w700, active ? Colors.white : ink)),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          chip(
            _filter.city.isEmpty ? 'Şehir' : _filter.city,
            _filter.city.isNotEmpty,
            () => _pick('Şehir', cities, _filter.city,
                (v) => setState(() => _filter = _filter.copyWith(city: v))),
            icon: Icons.location_on_rounded,
          ),
          chip(
            _filter.sport.isEmpty
                ? 'Branş'
                : (sports
                        .where((s) => s.code == _filter.sport)
                        .map((s) => s.label)
                        .firstOrNull ??
                    'Branş'),
            _filter.sport.isNotEmpty,
            () => _pick('Branş', sports, _filter.sport,
                (v) => setState(() => _filter = _filter.copyWith(sport: v))),
            icon: Icons.sports_volleyball_rounded,
          ),
          chip('Doğrulanmış', _filter.verifiedOnly,
              () => setState(() =>
                  _filter = _filter.copyWith(verifiedOnly: !_filter.verifiedOnly)),
              icon: Icons.verified_rounded),
          if (!_filter.isEmpty)
            chip('Temizle', false, () {
              _search.clear();
              setState(() => _filter = const DiscoverFilter());
            }, icon: Icons.close_rounded),
        ],
      ),
    );
  }

  Future<void> _pick(String title, List<FilterOption> options, String current,
      ValueChanged<String> onPick) async {
    if (options.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
        child: Column(children: [
          Text(title, style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(children: [
              ListTile(
                title: Text('Hepsi',
                    style: jakarta(13.5, FontWeight.w600, ink)),
                trailing: current.isEmpty
                    ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                    : null,
                onTap: () => Navigator.pop(ctx, ''),
              ),
              for (final o in options)
                ListTile(
                  title:
                      Text(o.label, style: jakarta(13.5, FontWeight.w600, ink)),
                  subtitle: Text('${o.count} kulüp',
                      style: jakarta(
                          11, FontWeight.w500, SwanColors.textSecondary)),
                  trailing: o.code == current
                      ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                      : null,
                  onTap: () => Navigator.pop(ctx, o.code),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (picked != null) onPick(picked);
  }

  Widget _card(bool isDark, Color ink, DiscoveredClub c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/kulup-profil', arguments: c.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          SocialAvatar(
            initials: c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
            imageUrl: c.logoUrl,
            size: 46,
            radius: 15,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(13.5, FontWeight.w800, ink)),
                  ),
                  if (c.isVerified) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.verified_rounded, size: 14, color: kTeal),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                    [
                      if ((c.sportName ?? '').isNotEmpty) c.sportName!,
                      if (c.where.isNotEmpty) c.where,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(
                        11, FontWeight.w600, SwanColors.textSecondary)),
                const SizedBox(height: 3),
                Text('${c.athleteCount} sporcu · ${c.coachCount} antrenör',
                    style: jakarta(
                        10.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
          if (c.isFollowing)
            const Icon(Icons.how_to_reg_rounded, size: 17, color: kTeal)
          else
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }
}

import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_city_picker.dart';
import '../../clubs/presentation/club_create_sheet.dart';
import '../../social/presentation/widgets/social_widgets.dart';

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
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final async = ref.watch(discoverClubsProvider(_filter));

    return SwanScaffold(
      appBar:
          swanModuleAppBar(context, title: 'Kulüpler & Akademiler', actions: [
        TextButton.icon(
          onPressed: () => showClubCreateSheet(context),
          icon: const Icon(Icons.add_circle_outline),
          label:
              Text('Kulüp Kur', style: SwanType.caption(context.swan.accent)),
        ),
      ]),
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                // Top Header & Create Club Action

                const SizedBox(height: 14),

                // Search & Filter Section for Registered Clubs
                Text(
                  'Kulüpleri keşfet',
                  style: SwanType.bodySm(ink, w: FontWeight.w800),
                ),
                const SizedBox(height: 10),

                // Arama
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(
                      () => _filter = _filter.copyWith(query: v.trim())),
                  style: SwanType.bodySm(ink),
                  decoration: InputDecoration(
                    hintText: 'Kulüp adı veya şehir ara…',
                    hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    filled: true,
                    fillColor: surf,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: line)),
                  ),
                ),
                const SizedBox(height: 10),

                _filterBar(isDark, ink, line),
                const SizedBox(height: 12),

                async.when(
                  loading: () => premiumLoading(),
                  error: (e, _) => premiumError(
                    context,
                    '$e',
                    onRetry: () => ref.invalidate(
                      discoverClubsProvider(_filter),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: line),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.travel_explore_rounded,
                                  size: 36, color: SwanColors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                _filter.isEmpty
                                    ? 'Henüz keşfedilecek kulüp yok'
                                    : 'Filtrelere uygun kulüp bulunamadı',
                                style: SwanType.bodySm(ink, w: FontWeight.w700),
                              ),
                              if (!_filter.isEmpty) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('Filtreleri temizle'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (final club in list) _card(isDark, ink, club),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _filterBar(bool isDark, Color ink, Color line) {
    final opts = ref.watch(filterOptionsProvider).valueOrNull ?? const [];
    final sports = opts.where((o) => o.kind == 'sport').toList();
    final sportLabel = sports
            .where((option) => option.code == _filter.sport)
            .map((option) => option.label)
            .firstOrNull ??
        'Branş';
    final activeCount = (_filter.city.isNotEmpty ? 1 : 0) +
        (_filter.sport.isNotEmpty ? 1 : 0) +
        (_filter.verifiedOnly ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showFilters(sports),
          icon: const Icon(Icons.tune_rounded),
          label:
              Text(activeCount == 0 ? 'Filtreler' : 'Filtreler ($activeCount)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: BorderSide(color: line),
            minimumSize: const Size(0, 44),
          ),
        ),
        if (activeCount > 0) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_filter.city.isNotEmpty)
                InputChip(
                  label: Text(_filter.city),
                  onDeleted: () => setState(
                    () => _filter = _filter.copyWith(city: ''),
                  ),
                ),
              if (_filter.sport.isNotEmpty)
                InputChip(
                  label: Text(sportLabel),
                  onDeleted: () => setState(
                    () => _filter = _filter.copyWith(sport: ''),
                  ),
                ),
              if (_filter.verifiedOnly)
                InputChip(
                  label: const Text('Doğrulanmış'),
                  onDeleted: () => setState(
                    () => _filter = _filter.copyWith(verifiedOnly: false),
                  ),
                ),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Temizle'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _clearFilters() {
    _search.clear();
    setState(() => _filter = const DiscoverFilter());
  }

  Future<void> _showFilters(List<FilterOption> sports) async {
    var draft = _filter;
    final selected = await showModalBottomSheet<DiscoverFilter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Kulüpleri filtrele',
                        style: SwanType.h2(context.swan.ink),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Vazgeç'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Konum'),
                  subtitle:
                      Text(draft.city.isEmpty ? 'Tüm şehirler' : draft.city),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final picked = await showSwanCityPicker(
                      context,
                      selectedCity: draft.city,
                    );
                    if (picked != null) {
                      setSheetState(
                        () => draft = draft.copyWith(city: picked.name),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text('Branş',
                    style:
                        SwanType.bodySm(context.swan.ink, w: FontWeight.w700)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Tümü'),
                          selected: draft.sport.isEmpty,
                          onSelected: (_) => setSheetState(
                            () => draft = draft.copyWith(sport: ''),
                          ),
                        ),
                        for (final sport in sports)
                          ChoiceChip(
                            label: Text(sport.label),
                            selected: draft.sport == sport.code,
                            onSelected: (_) => setSheetState(
                              () => draft = draft.copyWith(sport: sport.code),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yalnızca doğrulanmış kulüpler'),
                  value: draft.verifiedOnly,
                  onChanged: (value) => setSheetState(
                    () => draft = draft.copyWith(verifiedOnly: value),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheetState(
                        () => draft = DiscoverFilter(query: draft.query),
                      ),
                      child: const Text('Temizle'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, draft),
                      child: const Text('Sonuçları göster'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _filter = selected);
  }

  Widget _card(bool isDark, Color ink, DiscoveredClub c) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

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
                        style: SwanType.bodySm(ink, w: FontWeight.w800)),
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
                    style: SwanType.caption(SwanColors.textSecondary,
                        w: FontWeight.w600)),
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

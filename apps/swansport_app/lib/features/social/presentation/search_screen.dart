import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'widgets/social_widgets.dart';

/// Arama & Keşfet — Stitch Modern Athletic Bento Grid & Realtime Network Search.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  int _searchFilter = 0; // 0 hepsi, 1 kulüp, 2 antrenör, 3 sporcu
  int _selectedExploreCategory = 0;
  final Set<String> _followingIds = <String>{};

  List<SuggestionRow> _results = const [];
  bool _loading = false;
  String? _error;

  static const _exploreCategories = [
    ('#Tümü', Icons.bolt_rounded),
    ('#Kuvvet', Icons.fitness_center_rounded),
    ('#Koşu', Icons.directions_run_rounded),
    ('#Calisthenics', Icons.sports_gymnastics_rounded),
    ('#HIIT', Icons.timer_outlined),
    ('#Beslenme', Icons.restaurant_rounded),
    ('#Yoga', Icons.self_improvement_rounded),
    ('#Crossfit', Icons.speed_rounded),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(value));
  }

  Future<void> _run(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _query = trimmed;
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(socialServiceProvider).search(trimmed);
      if (!mounted || _query != trimmed) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  int get _clubCount => _results.where((r) => r.kind == 'club').length;
  int get _coachCount => _results.where((r) => r.kind == 'coach').length;
  int get _athleteCount => _results.where((r) => r.kind == 'athlete').length;

  List<SuggestionRow> get _visible => switch (_searchFilter) {
        1 => _results.where((r) => r.kind == 'club').toList(),
        2 => _results.where((r) => r.kind == 'coach').toList(),
        3 => _results.where((r) => r.kind == 'athlete').toList(),
        _ => _results,
      };

  void _toggleFollow(String id) {
    setState(() {
      if (_followingIds.contains(id)) {
        _followingIds.remove(id);
      } else {
        _followingIds.add(id);
      }
    });
    unawaited(
      ref.read(socialServiceProvider).setFollow(
            'profile',
            id,
            _followingIds.contains(id),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF061424) : SwanPalette.light.surface;
    final surfContainer = isDark ? const Color(0xFF132031) : const Color(0xFFF1F5F9);
    final surfHigh = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFE2E8F0);
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = isDark ? const Color(0xFF293547) : SwanPalette.light.line;

    final hasQuery = _query.trim().isNotEmpty;
    final list = _visible;

    final filterItems = [
      ('Tümü', _results.length),
      ('Kulüpler', _clubCount),
      ('Antrenörler', _coachCount),
      ('Sporcular', _athleteCount),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: surf,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                // Top Athletic Search Bar (Stitch Screen 25)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: surfContainer.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: kTeal.withValues(alpha: 0.2),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: kTeal, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  onChanged: _onChanged,
                                  onSubmitted: _run,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Sporcu, hareket, antrenman ara...',
                                    hintStyle: GoogleFonts.plusJakartaSans(
                                      color: SwanColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_ctrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _ctrl.clear();
                                    _onChanged('');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: surfHigh,
                                    ),
                                    child: Icon(Icons.close_rounded,
                                        size: 14, color: ink),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Camera / QR Scanner action
                      GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Barkod / QR Tarayıcı açılıyor...'),
                            backgroundColor: kTeal,
                          ),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: surfContainer.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kTeal.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(Icons.photo_camera_rounded,
                              size: 20, color: ink),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Filter action
                      GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Arama filtreleri aktif'),
                            backgroundColor: kTeal,
                          ),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: surfContainer.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: kTeal.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(Icons.tune_rounded, size: 20, color: ink),
                        ),
                      ),
                    ],
                  ),
                ),

                // Horizontal Filter Badges (Stitch Screen 25)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _exploreCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _exploreCategories[i];
                      final on = _selectedExploreCategory == i;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedExploreCategory = i);
                          if (i > 0 && !hasQuery) {
                            _ctrl.text = cat.$1.replaceAll('#', '');
                            _run(_ctrl.text);
                          } else if (i == 0 && !hasQuery) {
                            _ctrl.clear();
                            _run('');
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: on ? kTeal : surfContainer,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: on
                                ? [
                                    BoxShadow(
                                      color: kTeal.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.$2,
                                size: 15,
                                color: on
                                    ? const Color(0xFF003734)
                                    : SwanColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.$1,
                                style: GoogleFonts.plusJakartaSans(
                                  color: on ? const Color(0xFF003734) : ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Body: Either Live Search Results or Stitch Explore Bento Grid
                Expanded(
                  child: hasQuery
                      ? _buildSearchResults(
                          context: context,
                          filterItems: filterItems,
                          list: list,
                          surf: surf,
                          surfContainer: surfContainer,
                          surfHigh: surfHigh,
                          ink: ink,
                          line: line,
                        )
                      : _buildRealExploreFeed(
                          context: context,
                          surfContainer: surfContainer,
                          surfHigh: surfHigh,
                          ink: ink,
                          line: line,
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

  /// Live Search Results View
  Widget _buildSearchResults({
    required BuildContext context,
    required List<(String, int)> filterItems,
    required List<SuggestionRow> list,
    required Color surf,
    required Color surfContainer,
    required Color surfHigh,
    required Color ink,
    required Color line,
  }) {
    final c = context.swan;
    return Column(
      children: [
        // Sub-filter tabs (Tümü, Kulüpler, Antrenörler, Sporcular)
        Container(
          height: 38,
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filterItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final item = filterItems[i];
              final on = _searchFilter == i;
              return GestureDetector(
                onTap: () => setState(() => _searchFilter = i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? kTeal : surfContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Text(
                        item.$1,
                        style: GoogleFonts.plusJakartaSans(
                          color: on ? const Color(0xFF003734) : ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.$2 > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: on
                                ? Colors.black.withValues(alpha: 0.15)
                                : surfHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${item.$2}',
                            style: GoogleFonts.sora(
                              color: on ? const Color(0xFF003734) : kTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: Builder(
            builder: (_) {
              if (_loading) return premiumLoading();
              if (_error != null) return premiumError(context, _error!);
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            color: SwanColors.textSecondary, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Sonuç bulunamadı',
                          style: GoogleFonts.sora(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '“$_query” için eşleşen sporcu, kulüp veya antrenör bulunamadı.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: SwanColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _buildResultCard(c, list[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Real explore feed connected to real providers
  Widget _buildRealExploreFeed({
    required BuildContext context,
    required Color surfContainer,
    required Color surfHigh,
    required Color ink,
    required Color line,
  }) {
    final suggestions = ref.watch(suggestionsProvider).valueOrNull ?? const [];
    final clubs = ref.watch(myClubsProvider).valueOrNull ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Önerilen Sporcular & Antrenörler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Önerilen Sporcular & Antrenörler',
                style: GoogleFonts.sora(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${suggestions.length} Öneri',
                style: SwanType.caption(kTeal, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (suggestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: line),
              ),
              child: Text(
                'Şimdilik önerilecek hesap bulunamadı.',
                style: SwanType.bodySm(SwanColors.textSecondary),
              ),
            )
          else
            for (final s in suggestions.take(5))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: surfHigh,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: s.avatarUrl != null && s.avatarUrl!.isNotEmpty
                            ? Image.network(
                                s.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    s.initials,
                                    style: SwanType.bodySm(kTeal, w: FontWeight.w800),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  s.initials,
                                  style: SwanType.bodySm(kTeal, w: FontWeight.w800),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                s.name,
                                style: SwanType.bodySm(ink, w: FontWeight.w700),
                              ),
                              if (s.kind == 'club') ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.shield_rounded, size: 14, color: kTeal),
                              ],
                            ],
                          ),
                          if (s.subtitle != null && s.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              s.subtitle!,
                              style: SwanType.caption(SwanColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (s.kind == 'club') {
                          Navigator.pushNamed(context, '/kulupler');
                        } else {
                          Navigator.pushNamed(context, '/profil', arguments: {'id': s.id});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: kTeal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Görüntüle',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF003734),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

          const SizedBox(height: 20),

          // 2. Aktif Kulüplerim
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kulüp Ağlarım',
                style: GoogleFonts.sora(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/kulupler'),
                child: Text(
                  'Tüm Kulüpler',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (clubs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: kTeal, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Henüz bir kulübe katılmadınız',
                          style: SwanType.bodySm(ink, w: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SwanSport ağındaki doğrulanmış kulüpleri inceleyin.',
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            for (final c in clubs)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(Icons.shield_rounded, color: kTeal, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                          Text(c.role ?? 'Üye', style: SwanType.caption(SwanColors.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: SwanColors.textSecondary),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildResultCard(SwanPalette c, SuggestionRow r) {
    if (r.isClub) {
      return _buildClubCard(c, r);
    } else if (r.kind == 'coach') {
      return _buildCoachCard(c, r);
    } else {
      return _buildAthleteCard(c, r);
    }
  }

  Widget _buildClubCard(SwanPalette c, SuggestionRow r) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                  border: Border.all(color: c.line),
                ),
                child: r.avatarUrl != null && r.avatarUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                        child: Image.network(r.avatarUrl!, fit: BoxFit.cover),
                      )
                    : Icon(Icons.shield_rounded, color: c.accent, size: 28),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.h3(c.ink),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.verified_rounded, size: 16, color: c.accent),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: c.inkMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            r.subtitle ?? 'İstanbul',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Kulüp',
                  style: SwanType.caption(c.accent, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.sm, vertical: SwanSpace.xs),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_rounded, size: 16, color: c.accent),
                const SizedBox(width: 4),
                Text('Kadro & Tesisler',
                    style: SwanType.caption(c.ink, w: FontWeight.w600)),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushNamed(
                      context, '/kulup-detay',
                      arguments: r.id),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.accentFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'İncele',
                      style: SwanType.caption(Colors.white, w: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(SwanPalette c, SuggestionRow r) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          SocialAvatar(
            initials: r.initials,
            imageUrl: r.avatarUrl,
            size: 48,
            gradientIndex: r.name.length % 4,
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.body(c.ink, w: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.verified_rounded, size: 16, color: c.accent),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.subtitle ?? 'Başantrenör',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(c.accent, w: FontWeight.w600),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () =>
                Navigator.pushNamed(context, '/profil', arguments: r.id),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: c.line),
              ),
              child: Text(
                'Görüntüle',
                style: SwanType.caption(c.ink, w: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteCard(SwanPalette c, SuggestionRow r) {
    final isFollowing = _followingIds.contains(r.id);

    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              SocialAvatar(
                initials: r.initials,
                imageUrl: r.avatarUrl,
                size: 48,
                gradientIndex: r.name.length % 4,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.body(c.ink, w: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'U18',
                        style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.subtitle ?? 'Lisanslı Sporcu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _toggleFollow(r.id),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isFollowing ? c.accentFill : c.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isFollowing ? c.accent : c.line),
              ),
              child: Text(
                isFollowing ? 'Takipte' : 'Takip Et',
                style: SwanType.caption(
                  isFollowing ? Colors.white : c.ink,
                  w: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

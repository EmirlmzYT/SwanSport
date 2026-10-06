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
  bool _challengeJoined = false;
  final Set<String> _likedExploreItems = <String>{};
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
                      : _buildExploreBentoFeed(
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

  /// Stitch Screen 25 Full Explore Bento Grid & Challenge Feed
  Widget _buildExploreBentoFeed({
    required BuildContext context,
    required Color surfContainer,
    required Color surfHigh,
    required Color ink,
    required Color line,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Trend Challenge Banner (Stitch Screen 25)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  surfHigh,
                  surfContainer,
                  const Color(0xFF020F1F),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 18,
                  offset: Offset(0, 6),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 14, color: kTeal),
                          const SizedBox(width: 4),
                          Text(
                            'TREND CHALLENGE',
                            style: GoogleFonts.plusJakartaSans(
                              color: kTeal,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            size: 16, color: Color(0xFFFFB6A4)),
                        const SizedBox(width: 4),
                        Text(
                          '1.000 XP + Swan Rozeti',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFFB6A4),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '30 Günlük Swan Push-Up',
                  style: GoogleFonts.sora(
                    color: ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Her gün formunu mükemmelleştir, patlayıcı itiş gücü kazan ve global sıralamada yerini al.',
                  style: GoogleFonts.plusJakartaSans(
                    color: SwanColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 26,
                          child: Stack(
                            children: [
                              _avatarCircle('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100', 0),
                              _avatarCircle('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', 16),
                              Positioned(
                                left: 32,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: kTeal,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+4k',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF003734),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '4.280 Sporcu',
                          style: GoogleFonts.plusJakartaSans(
                            color: SwanColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _challengeJoined = !_challengeJoined);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_challengeJoined
                                ? 'Meydan okumaya katıldın! İlk gün antrenmanı atandı.'
                                : 'Meydan okumadan ayrıldın.'),
                            backgroundColor: kTeal,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _challengeJoined ? surfHigh : kTeal,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _challengeJoined
                              ? null
                              : [
                                  BoxShadow(
                                    color: kTeal.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _challengeJoined
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_rounded,
                              size: 16,
                              color: _challengeJoined
                                  ? kTeal
                                  : const Color(0xFF003734),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _challengeJoined ? 'Katıldın!' : 'Meydan Oku',
                              style: GoogleFonts.plusJakartaSans(
                                color: _challengeJoined
                                    ? kTeal
                                    : const Color(0xFF003734),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Community Feed Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.dynamic_feed_rounded,
                      size: 20, color: kTeal),
                  const SizedBox(width: 8),
                  Text(
                    'Topluluk Akışı',
                    style: GoogleFonts.sora(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Akış yenilendi'),
                    backgroundColor: kTeal,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Tazele',
                      style: GoogleFonts.plusJakartaSans(
                        color: kTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.refresh_rounded, size: 14, color: kTeal),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3-Column Asymmetric Bento Grid (Stitch Screen 25)
          // Row 1: Big card (2-col) + 2 small cards (1-col stacked)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big 2x2 Feature Video Card
              Expanded(
                flex: 2,
                child: Container(
                  height: 236,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&auto=format&fit=crop&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.88),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.videocam_rounded,
                                          size: 13, color: kTeal),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Form Analizi',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: kTeal,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      size: 18, color: kTeal),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Koparma Tekniği & Bar Hızı',
                                  style: GoogleFonts.sora(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                            Icons.visibility_outlined,
                                            size: 12,
                                            color: Colors.white70),
                                        const SizedBox(width: 4),
                                        Text('42.5K',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white70,
                                                fontSize: 10)),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (_likedExploreItems
                                              .contains('snatch')) {
                                            _likedExploreItems.remove('snatch');
                                          } else {
                                            _likedExploreItems.add('snatch');
                                          }
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          Icon(
                                            _likedExploreItems.contains('snatch')
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            size: 14,
                                            color: _likedExploreItems
                                                    .contains('snatch')
                                                ? const Color(0xFFFFB6A4)
                                                : Colors.white70,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('1.4K',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                      color: Colors.white70,
                                                      fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Small Column (2 cards)
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // Small Card 1: PR Metric Tile
                    Container(
                      height: 114,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: surfContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF8C6F)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PR!',
                                  style: GoogleFonts.sora(
                                    color: const Color(0xFFFF8C6F),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(Icons.verified_rounded,
                                  size: 14, color: kTeal),
                            ],
                          ),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  '180',
                                  style: GoogleFonts.sora(
                                    color: kTeal,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'KG DEADLIFT',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: SwanColors.textSecondary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '@selin_fit',
                                style: GoogleFonts.plusJakartaSans(
                                  color: SwanColors.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                              const Icon(Icons.favorite_rounded,
                                  size: 11, color: Color(0xFFFFB6A4)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Small Card 2: Runner Map Route
                    Container(
                      height: 114,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1452626038306-9aae5e071dd3?w=500&auto=format&fit=crop&q=80',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '12.4 km',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: kTeal,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Pace 4:32',
                                        style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white, fontSize: 9)),
                                    const Icon(Icons.route_rounded,
                                        size: 12, color: Colors.white70),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: 3 Square Cards
          Row(
            children: [
              // Small Card 3: Macro Bowl
              Expanded(
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500&auto=format&fit=crop&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Macro Bowl',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                              const Icon(Icons.favorite_border_rounded,
                                  size: 12, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Small Card 4: Calisthenics Bar Flow
              Expanded(
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=500&auto=format&fit=crop&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Bar Flow',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                              Text('8.1K',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Small Card 5: Kettlebell Tabata
              Expanded(
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=500&auto=format&fit=crop&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tabata KB',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                              const Icon(Icons.play_circle_outline_rounded,
                                  size: 13, color: kTeal),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Movement of the Day: Micro Video Guide Card (Stitch Screen 25)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.smart_display_rounded,
                      size: 20, color: kTeal),
                  const SizedBox(width: 8),
                  Text(
                    'Günün İlham Hareketi',
                    style: GoogleFonts.sora(
                      color: ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: surfContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '0:45 Rehber',
                  style: GoogleFonts.plusJakartaSans(
                    color: kTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=500&auto=format&fit=crop&q=80',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: kTeal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 18, color: Color(0xFF003734)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOBİLİTE & DENGE',
                        style: GoogleFonts.plusJakartaSans(
                          color: kTeal,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tek Bacak Pistol Squat',
                        style: GoogleFonts.sora(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diz kapağı stabilizasyonu ve ayak bileği esnekliği için 3 altın kural.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: SwanColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 12, color: kTeal),
                              const SizedBox(width: 4),
                              Text(
                                '3 Set x 8 Tekrar',
                                style: GoogleFonts.plusJakartaSans(
                                  color: SwanColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hareketi Başlat seçildi'),
                                backgroundColor: kTeal,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Başla',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: kTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    size: 16, color: kTeal),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarCircle(String url, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF132031), width: 1.5),
          image: DecorationImage(
            image: NetworkImage(url),
            fit: BoxFit.cover,
          ),
        ),
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

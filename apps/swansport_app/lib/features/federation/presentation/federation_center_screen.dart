import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_module_app_bar.dart';
import '../../../app/widgets/swan_scaffold.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../live_match/presentation/league_standings_view.dart';
import '../../live_match/presentation/live_match_widgets.dart';

class FederationCenterScreen extends ConsumerStatefulWidget {
  const FederationCenterScreen({
    super.key,
    this.initialTab = 0,
    this.initialSport,
    this.initialCity,
  });

  final int initialTab;
  final String? initialSport;
  final String? initialCity;

  @override
  ConsumerState<FederationCenterScreen> createState() =>
      _FederationCenterScreenState();
}

class _FederationCenterScreenState
    extends ConsumerState<FederationCenterScreen> {
  late int _selectedTab;
  late FederationCenterFilter _filter;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _sports = [
    'Tümü',
    'futbol',
    'basketbol',
    'voleybol',
    'tenis',
    'yuzme',
    'atletizm',
  ];

  static const List<String> _sportLabels = [
    'Tümü',
    'Futbol',
    'Basketbol',
    'Voleybol',
    'Tenis',
    'Yüzme',
    'Atletizm',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _filter = FederationCenterFilter(
      sportCode: widget.initialSport,
      cityCode: widget.initialCity,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);
    final liveMatchHubEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub));
    final leagueStandingsEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings));
    final async = ref.watch(federationCenterOverviewProvider(_filter));

    return SwanScaffold(
      backgroundColor: c.bg,
      appBar: swanModuleAppBar(
        context,
        title: 'Federasyon Yayın Merkezi',
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: Icon(Icons.refresh_rounded, color: c.ink),
            onPressed: () =>
                ref.invalidate(federationCenterOverviewProvider(_filter)),
          ),
        ],
      ),
      bottomNavigationBar: const SwanBottomNav(),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(federationCenterOverviewProvider(_filter));
            await ref.read(federationCenterOverviewProvider(_filter).future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. ÜST HERO & ARAMA / FİLTRE ÇUBUĞU
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SwanSpace.lg,
                    SwanSpace.md,
                    SwanSpace.lg,
                    SwanSpace.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderHero(context, c, access),
                      const SizedBox(height: SwanSpace.md),
                      _buildSearchAndFilters(c),
                      const SizedBox(height: SwanSpace.md),
                      _buildTabs(
                        c,
                        liveMatchHubEnabled: liveMatchHubEnabled,
                      ),
                    ],
                  ),
                ),
              ),

              // 2. İÇERİK SLIVER'I
              ...async.when(
                loading: () => [
                  SliverToBoxAdapter(child: premiumLoading()),
                ],
                error: (e, _) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(SwanSpace.lg),
                      child: premiumError(
                        context,
                        '$e',
                        onRetry: () => ref.invalidate(
                          federationCenterOverviewProvider(_filter),
                        ),
                      ),
                    ),
                  ),
                ],
                data: (overview) => [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      SwanSpace.lg,
                      0,
                      SwanSpace.lg,
                      SwanSpace.xl * 5,
                    ),
                    sliver: _buildTabContent(
                      context,
                      c,
                      overview,
                      liveMatchHubEnabled: liveMatchHubEnabled,
                      leagueStandingsEnabled: leagueStandingsEnabled,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderHero(
    BuildContext context,
    SwanPalette c,
    SwanAccess access,
  ) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(SwanSpace.xs),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_rounded, size: 20, color: c.accent),
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resmi Müsabaka & Yayın Platformu',
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                    Text(
                      'Tescilli ligler, hakemli maçlar, canlı skorlar ve resmi sonuçlar',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (access.hasActiveFederationRole) ...[
            const SizedBox(height: SwanSpace.md),
            Container(
              padding: const EdgeInsets.all(SwanSpace.sm),
              decoration: BoxDecoration(
                color: c.accentFill.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(SwanRadius.md),
                border: Border.all(color: c.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 18,
                    color: c.accent,
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  Expanded(
                    child: Text(
                      'Federasyon / MHK Görev Yetkisi Aktif',
                      style: SwanType.caption(c.accent, w: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showPendingResultsSheet(context, c),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SwanSpace.sm,
                        vertical: SwanSpace.xs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Bekleyen Sonuçlar', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/calendar'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SwanSpace.sm,
                        vertical: SwanSpace.xs,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Takvim Aç', style: SwanType.caption(c.accent)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: (val) =>
              setState(() => _filter = _filter.copyWith(query: val)),
          style: SwanType.bodySm(c.ink),
          decoration: InputDecoration(
            hintText: 'Müsabaka, kulüp veya program ara…',
            hintStyle: SwanType.caption(c.inkMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.inkMuted),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: SwanSpace.sm,
              horizontal: SwanSpace.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SwanRadius.md),
              borderSide: BorderSide(color: c.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SwanRadius.md),
              borderSide: BorderSide(color: c.line),
            ),
          ),
        ),
        const SizedBox(height: SwanSpace.sm),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _sports.length,
            separatorBuilder: (_, __) => const SizedBox(width: SwanSpace.xs),
            itemBuilder: (context, i) {
              final code = _sports[i];
              final label = _sportLabels[i];
              final isSelected =
                  (code == 'Tümü' && _filter.sportCode == null) ||
                      _filter.sportCode == code;

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                labelStyle: SwanType.caption(
                  isSelected ? c.onAccent : c.ink,
                  w: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                backgroundColor: c.surface,
                selectedColor: c.accentFill,
                side: BorderSide(
                  color: isSelected ? c.accent : c.line,
                ),
                onSelected: (_) {
                  setState(() {
                    if (code == 'Tümü') {
                      _filter = _filter.copyWith(clearSport: true);
                    } else {
                      _filter = _filter.copyWith(sportCode: code);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(
    SwanPalette c, {
    required bool liveMatchHubEnabled,
  }) {
    return SwanPillTabs(
      labels: [
        liveMatchHubEnabled ? 'Bugün & Canlı' : 'Bugün',
        'Fikstür & Takvim',
        'Puan Durumu',
      ],
      selected: _selectedTab,
      onSelect: (index) => setState(() => _selectedTab = index),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    SwanPalette c,
    FederationCenterOverview overview, {
    required bool liveMatchHubEnabled,
    required bool leagueStandingsEnabled,
  }) {
    switch (_selectedTab) {
      case 0:
        return _buildTodayAndLiveSliver(
          context,
          c,
          overview,
          liveMatchHubEnabled: liveMatchHubEnabled,
        );
      case 1:
        return _buildUpcomingSliver(context, c, overview);
      case 2:
        return leagueStandingsEnabled
            ? _buildStandingsSliver(context, c, overview)
            : _buildFeatureUnavailableSliver(
                c,
                icon: Icons.leaderboard_rounded,
                message: 'Puan durumu henüz kullanıma açılmadı.',
              );
      default:
        return _buildTodayAndLiveSliver(
          context,
          c,
          overview,
          liveMatchHubEnabled: liveMatchHubEnabled,
        );
    }
  }

  Widget _buildTodayAndLiveSliver(
    BuildContext context,
    SwanPalette c,
    FederationCenterOverview overview, {
    required bool liveMatchHubEnabled,
  }) {
    final matches = overview.todayMatches;

    if (matches.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SwanSpace.xl * 2),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.sports_rounded, size: 40, color: c.inkMuted),
                const SizedBox(height: SwanSpace.sm),
                Text(
                  liveMatchHubEnabled
                      ? 'Bugün için planlanmış resmi maç bulunamadı'
                      : 'Bugünün canlı skorları henüz kullanıma açılmadı',
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: SwanSpace.xs),
                Text(
                  liveMatchHubEnabled
                      ? 'Fikstür ve takvim sekmesinden yaklaşan resmi maçları inceleyebilirsin.'
                      : 'Fikstür ve takvim sekmesinden yayımlanmış resmi programı inceleyebilirsin.',
                  style: SwanType.caption(c.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: SwanSpace.md),
      itemBuilder: (context, index) {
        final match = matches[index];
        return LiveMatchCard(match: match);
      },
    );
  }

  Widget _buildUpcomingSliver(
    BuildContext context,
    SwanPalette c,
    FederationCenterOverview overview,
  ) {
    final activities = overview.upcomingActivities;

    if (activities.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SwanSpace.xl * 2),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_note_rounded, size: 40, color: c.inkMuted),
                const SizedBox(height: SwanSpace.sm),
                Text(
                  'Filtrelere uygun resmi faaliyet bulunamadı',
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: SwanSpace.sm),
      itemBuilder: (context, index) {
        final a = activities[index];
        return Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Center(
                  child: Icon(
                    a.isMatch
                        ? Icons.sports_score_rounded
                        : Icons.event_rounded,
                    color: c.accent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    Text(
                      '${a.federationName} • ${a.seasonLabel}',
                      style: SwanType.caption(c.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (a.isMatch)
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/canli-mac/${a.id}'),
                  child: Text('Detay', style: SwanType.caption(c.accent)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandingsSliver(
    BuildContext context,
    SwanPalette c,
    FederationCenterOverview overview,
  ) {
    final leagues = overview.leagues;

    if (leagues.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SwanSpace.xl * 2),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.leaderboard_rounded, size: 40, color: c.inkMuted),
                const SizedBox(height: SwanSpace.sm),
                Text(
                  'Kayıtlı resmi lig puan tablosu bulunamadı',
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: leagues.length,
      separatorBuilder: (_, __) => const SizedBox(height: SwanSpace.md),
      itemBuilder: (context, index) {
        final league = leagues[index];
        return Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            onTap: () => _showLeagueStandingsSheet(context, c, league),
            child: Container(
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SwanRadius.lg),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(SwanSpace.sm),
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events_outlined,
                      size: 20,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          league.name,
                          style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                        ),
                        const SizedBox(height: SwanSpace.xs),
                        Text(
                          '${league.sportCode.toUpperCase()} • ${league.cityCode ?? "Genel"} Puan Durumu',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.inkMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLeagueStandingsSheet(
    BuildContext context,
    SwanPalette c,
    StandingsLeague league,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SwanRadius.lg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: SwanSpace.md),
                    decoration: BoxDecoration(
                      color: c.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(league.name, style: SwanType.h3(c.ink)),
                          const SizedBox(height: SwanSpace.xs),
                          Text(
                            '${liveSportName(league.sportCode)}${league.cityCode == null ? '' : ' • İl ${league.cityCode}'} • Puan: ${league.winPoints}/${league.drawPoints}/${league.lossPoints}',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.inkMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.md),
                LeagueStandingsView(
                  key: ValueKey('league-standings-${league.id}'),
                  orgId: league.id,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPendingResultsSheet(BuildContext context, SwanPalette c) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SwanRadius.lg),
        ),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final async = ref.watch(federationPendingResultsProvider(0));
          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, scrollController) => SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(SwanSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: SwanSpace.md),
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bekleyen Resmi Sonuçlar', style: SwanType.h3(c.ink)),
                              const SizedBox(height: SwanSpace.xs),
                              Text(
                                'Hakem raporu veya itiraz sonrası tescil bekleyen müsabakalar',
                                style: SwanType.caption(c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: c.inkMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.md),
                    async.when(
                      loading: () => Center(child: Padding(padding: const EdgeInsets.all(SwanSpace.xl), child: premiumLoading())),
                      error: (err, _) => premiumError(
                        context,
                        '$err',
                        onRetry: () => ref.invalidate(federationPendingResultsProvider(0)),
                      ),
                      data: (matches) {
                        if (matches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: SwanSpace.xl * 2),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 44, color: c.accent),
                                  const SizedBox(height: SwanSpace.sm),
                                  Text(
                                    'Bekleyen resmi tescil talebi bulunmuyor',
                                    style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                                  ),
                                  const SizedBox(height: SwanSpace.xs),
                                  Text(
                                    'Tüm tamamlanan maçlar tescil edilmiş durumda.',
                                    style: SwanType.caption(c.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final match in matches)
                              Padding(
                                padding: const EdgeInsets.only(bottom: SwanSpace.md),
                                child: Container(
                                  padding: const EdgeInsets.all(SwanSpace.md),
                                  decoration: BoxDecoration(
                                    color: c.bg,
                                    borderRadius: BorderRadius.circular(SwanRadius.md),
                                    border: Border.all(color: c.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.xs, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: c.accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(SwanRadius.sm),
                                            ),
                                            child: Text(
                                              'V${match.version} Tescil',
                                              style: SwanType.caption(c.accent, w: FontWeight.w700),
                                            ),
                                          ),
                                          const SizedBox(width: SwanSpace.xs),
                                          Text(
                                            liveSportName(match.sportCode),
                                            style: SwanType.caption(c.inkMuted),
                                          ),
                                          const Spacer(),
                                          if (match.startsAt != null)
                                            Text(liveStartTime(match.startsAt!), style: SwanType.caption(c.inkMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: SwanSpace.sm),
                                      Text(
                                        '${match.homeName ?? "Ev Sahibi"} — ${match.awayName ?? "Deplasman"}',
                                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                                      ),
                                      const SizedBox(height: SwanSpace.xs),
                                      Text(match.name, style: SwanType.caption(c.inkMuted)),
                                      if (match.location != null && match.location!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(match.location!, style: SwanType.caption(c.inkMuted)),
                                      ],
                                      const SizedBox(height: SwanSpace.md),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showPublishResultDialog(context, ref, c, match),
                                          icon: const Icon(Icons.publish_rounded, size: 16),
                                          label: const Text('Sonucu Tescil Et / Yayımla'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: c.accent,
                                            foregroundColor: c.onAccent,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPublishResultDialog(
    BuildContext context,
    WidgetRef ref,
    SwanPalette c,
    FederationPendingMatch match,
  ) {
    final homeController = TextEditingController();
    final awayController = TextEditingController();
    final reasonController = TextEditingController(text: match.version == 0 ? 'Hakem onaylı resmi maç sonucu tescili' : 'MHK tescil kararı');
    var isSubmitting = false;

    showDialog<void>(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.lg)),
            title: Text('Resmi Sonuç Tescili (V${match.version + 1})', style: SwanType.h3(c.ink)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${match.homeName ?? "Ev"} vs ${match.awayName ?? "Deplasman"}', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  const SizedBox(height: SwanSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: homeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: match.homeName ?? 'Ev Skor',
                            filled: true,
                            fillColor: c.bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: SwanSpace.sm),
                        child: Text(':', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: awayController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: match.awayName ?? 'Dep Skor',
                            filled: true,
                            fillColor: c.bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SwanSpace.md),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Tescil / Revizyon Gerekçesi',
                      hintText: 'Örn: MHK onaylı resmi müsabaka tescili',
                      filled: true,
                      fillColor: c.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgContext),
                child: Text('İptal', style: SwanType.bodySm(c.inkMuted)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final hs = int.tryParse(homeController.text.trim());
                        final as = int.tryParse(awayController.text.trim());
                        final reason = reasonController.text.trim();

                        if (hs == null || as == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen geçerli sayısal skorlar girin.')),
                          );
                          return;
                        }
                        if (reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen tescil gerekçesi belirtin.')),
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        try {
                          final service = ref.read(federationRecordsServiceProvider);
                          if (service == null) throw StateError('Sunucu bağlantısı aktif değil');

                          await service.publishResult(
                            matchId: match.id,
                            protocol: {'type': 'score', 'home': hs, 'away': as},
                            reason: reason,
                            expectedVersion: match.version,
                          );

                          if (dlgContext.mounted) Navigator.pop(dlgContext);
                          ref.invalidate(federationPendingResultsProvider(0));
                          ref.invalidate(federationCenterOverviewProvider(_filter));

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Resmi sonuç başarıyla tescil edildi ve yayımlandı.')),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tescil işlemi başarısız: $e')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                ),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Tescil Et'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureUnavailableSliver(
    SwanPalette c, {
    required IconData icon,
    required String message,
  }) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SwanSpace.xl * 2),
          child: Center(
            child: Column(
              children: [
                Icon(icon, size: 40, color: c.inkMuted),
                const SizedBox(height: SwanSpace.sm),
                Text(message, style: SwanType.bodySm(c.inkMuted)),
              ],
            ),
          ),
        ),
      );
}

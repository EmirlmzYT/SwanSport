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
import '../../live_match/presentation/match_follow_button.dart';

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
  int _bulletinFilterIndex = 0;
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
    final federationBulletinEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.federationBulletin));
    final liveMatchNotificationsEnabled =
        ref.watch(featureEnabledProvider(FeatureFlags.liveMatchNotifications));
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
                        federationBulletinEnabled: federationBulletinEnabled,
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
                      federationBulletinEnabled: federationBulletinEnabled,
                      liveMatchNotificationsEnabled:
                          liveMatchNotificationsEnabled,
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
          if (access.hasActiveFederationRole || access.isPlatformAdmin) ...[
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
                      access.hasActiveFederationRole
                          ? 'Federasyon / MHK Görev Yetkisi Aktif'
                          : 'Platform Yöneticisi Yetkisi Aktif',
                      style: SwanType.caption(c.accent, w: FontWeight.w700),
                    ),
                  ),
                  if (access.canPublishFederationResults) ...[
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
                      child: Text(
                        'Bekleyen Sonuçlar',
                        style: SwanType.caption(c.accent, w: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: SwanSpace.xs),
                  ],
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
    required bool federationBulletinEnabled,
  }) {
    return SwanPillTabs(
      labels: [
        liveMatchHubEnabled ? 'Bugün & Canlı' : 'Bugün',
        'Fikstür & Takvim',
        'Puan Durumu',
        if (federationBulletinEnabled) 'Disiplin & Bülten',
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
    required bool federationBulletinEnabled,
    required bool liveMatchNotificationsEnabled,
  }) {
    switch (_selectedTab) {
      case 0:
        return _buildTodayAndLiveSliver(
          context,
          c,
          overview,
          liveMatchHubEnabled: liveMatchHubEnabled,
          liveMatchNotificationsEnabled: liveMatchNotificationsEnabled,
        );
      case 1:
        return _buildUpcomingSliver(
          context,
          c,
          overview,
          liveMatchNotificationsEnabled: liveMatchNotificationsEnabled,
        );
      case 2:
        return leagueStandingsEnabled
            ? _buildStandingsSliver(context, c, overview)
            : _buildFeatureUnavailableSliver(
                c,
                icon: Icons.leaderboard_rounded,
                message: 'Puan durumu henüz kullanıma açılmadı.',
              );
      case 3:
        return federationBulletinEnabled
            ? _buildBulletinSliver(context, c, overview)
            : _buildTodayAndLiveSliver(
                context,
                c,
                overview,
                liveMatchHubEnabled: liveMatchHubEnabled,
                liveMatchNotificationsEnabled: liveMatchNotificationsEnabled,
              );
      default:
        return _buildTodayAndLiveSliver(
          context,
          c,
          overview,
          liveMatchHubEnabled: liveMatchHubEnabled,
          liveMatchNotificationsEnabled: liveMatchNotificationsEnabled,
        );
    }
  }

  Widget _buildTodayAndLiveSliver(
    BuildContext context,
    SwanPalette c,
    FederationCenterOverview overview, {
    required bool liveMatchHubEnabled,
    required bool liveMatchNotificationsEnabled,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LiveMatchCard(match: match),
            if (liveMatchNotificationsEnabled)
              Padding(
                padding: const EdgeInsets.only(bottom: SwanSpace.md),
                child: MatchFollowButton(matchId: match.matchId),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingSliver(
    BuildContext context,
    SwanPalette c,
    FederationCenterOverview overview, {
    required bool liveMatchNotificationsEnabled,
  }) {
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
              if (a.isMatch) ...[
                if (liveMatchNotificationsEnabled)
                  Padding(
                    padding: const EdgeInsets.only(right: SwanSpace.xs),
                    child: MatchFollowButton(
                      matchId: a.id,
                      compact: true,
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/canli-mac/${a.id}'),
                  child: Text('Detay', style: SwanType.caption(c.accent)),
                ),
              ],
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

  Widget _buildBulletinSliver(
    BuildContext context,
    SwanPalette c,
    FederationCenterOverview overview,
  ) {
    final decisions = overview.disciplinaryDecisions;
    final notices = overview.notices;

    final showDecisions =
        _bulletinFilterIndex == 0 || _bulletinFilterIndex == 1;
    final showNotices = _bulletinFilterIndex == 0 || _bulletinFilterIndex == 2;

    final visibleDecisions =
        showDecisions ? decisions : const <FederationDisciplinaryItem>[];
    final visibleNotices =
        showNotices ? notices : const <FederationNoticeItem>[];

    final isEmpty = visibleDecisions.isEmpty && visibleNotices.isEmpty;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: SwanSpace.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildBulletinFilterChip(
                    c,
                    label: 'Tümü',
                    index: 0,
                    count: overview.bulletinCount,
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  _buildBulletinFilterChip(
                    c,
                    label: 'Disiplin',
                    index: 1,
                    count: decisions.length,
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  _buildBulletinFilterChip(
                    c,
                    label: 'Duyurular',
                    index: 2,
                    count: notices.length,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: SwanSpace.xl * 2),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.gavel_rounded, size: 40, color: c.inkMuted),
                    const SizedBox(height: SwanSpace.sm),
                    Text(
                      'Kayıtlı disiplin kararı veya resmi duyuru bulunamadı',
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          if (visibleDecisions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: SwanSpace.sm),
                child: Row(
                  children: [
                    Icon(Icons.gavel_rounded, size: 16, color: c.danger),
                    const SizedBox(width: SwanSpace.xs),
                    Text(
                      'Resmi Disiplin Kararları (${visibleDecisions.length})',
                      style: SwanType.caption(c.ink, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.separated(
              itemCount: visibleDecisions.length,
              separatorBuilder: (_, __) => const SizedBox(height: SwanSpace.md),
              itemBuilder: (context, index) {
                final item = visibleDecisions[index];
                return _buildDisciplinaryCard(context, c, item);
              },
            ),
            if (visibleNotices.isNotEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(height: SwanSpace.lg),
              ),
          ],
          if (visibleNotices.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: SwanSpace.sm),
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, size: 16, color: c.accent),
                    const SizedBox(width: SwanSpace.xs),
                    Text(
                      'Müsabaka & Statü Duyuruları (${visibleNotices.length})',
                      style: SwanType.caption(c.ink, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            SliverList.separated(
              itemCount: visibleNotices.length,
              separatorBuilder: (_, __) => const SizedBox(height: SwanSpace.md),
              itemBuilder: (context, index) {
                final notice = visibleNotices[index];
                return _buildNoticeCard(context, c, notice);
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBulletinFilterChip(
    SwanPalette c, {
    required String label,
    required int index,
    required int count,
  }) {
    final isSelected = _bulletinFilterIndex == index;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      labelStyle: SwanType.caption(
        isSelected ? c.onAccent : c.ink,
        w: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: c.surface,
      selectedColor: c.accentFill,
      side: BorderSide(color: isSelected ? c.accent : c.line),
      onSelected: (_) => setState(() => _bulletinFilterIndex = index),
    );
  }

  Widget _buildDisciplinaryCard(
    BuildContext context,
    SwanPalette c,
    FederationDisciplinaryItem item,
  ) {
    final Color badgeColor;
    final Color badgeBg;
    final IconData badgeIcon;

    if (item.isSuspension) {
      badgeColor = c.danger;
      badgeBg = c.danger.withValues(alpha: 0.1);
      badgeIcon = Icons.block_rounded;
    } else if (item.isWarning) {
      badgeColor = const Color(0xFFF59E0B);
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      badgeIcon = Icons.warning_amber_rounded;
    } else if (item.isFine) {
      badgeColor = c.ink;
      badgeBg = c.bg;
      badgeIcon = Icons.attach_money_rounded;
    } else {
      badgeColor = c.accent;
      badgeBg = c.accent.withValues(alpha: 0.1);
      badgeIcon = Icons.gavel_rounded;
    }

    final dateStr =
        '${item.createdAt.day.toString().padLeft(2, '0')}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.year}';

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
                padding: const EdgeInsets.symmetric(
                  horizontal: SwanSpace.sm,
                  vertical: SwanSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  liveSportName(item.sportCode).toUpperCase(),
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SwanSpace.sm,
                  vertical: SwanSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: SwanSpace.xs),
                    Text(
                      item.penaltyLabel,
                      style: SwanType.caption(badgeColor, w: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(dateStr, style: SwanType.caption(c.inkMuted)),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Row(
            children: [
              Text(
                item.clubName,
                style: SwanType.bodySm(c.ink, w: FontWeight.w700),
              ),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: Text(
                  '• ${item.athleteDisplay}',
                  style: SwanType.caption(c.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SwanSpace.sm),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Text(
              item.reason,
              style: SwanType.caption(c.ink),
            ),
          ),
          if (item.matchTitle.isNotEmpty || item.programName.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(
              item.matchTitle.isNotEmpty
                  ? '${item.programName} • ${item.matchTitle}'
                  : item.programName,
              style: SwanType.caption(c.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeCard(
    BuildContext context,
    SwanPalette c,
    FederationNoticeItem notice,
  ) {
    final Color badgeColor = notice.isCancellation
        ? c.danger
        : (notice.isPostponement ? c.accent : c.inkMuted);
    final String badgeLabel = notice.isCancellation
        ? 'İPTAL'
        : (notice.isPostponement ? 'ERTELEME' : 'RESMİ BİLDİRİM');
    final IconData badgeIcon = notice.isCancellation
        ? Icons.cancel_outlined
        : (notice.isPostponement
            ? Icons.update_rounded
            : Icons.info_outline_rounded);

    final dateStr =
        '${notice.publishedAt.day.toString().padLeft(2, '0')}.${notice.publishedAt.month.toString().padLeft(2, '0')}.${notice.publishedAt.year}';

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
                padding: const EdgeInsets.symmetric(
                  horizontal: SwanSpace.sm,
                  vertical: SwanSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: SwanSpace.xs),
                    Text(
                      badgeLabel,
                      style: SwanType.caption(badgeColor, w: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SwanSpace.sm,
                  vertical: SwanSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  liveSportName(notice.sportCode).toUpperCase(),
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(dateStr, style: SwanType.caption(c.inkMuted)),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Text(
            notice.title,
            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(
            notice.body,
            style: SwanType.caption(c.inkMuted),
          ),
          if (notice.matchId != null) ...[
            const SizedBox(height: SwanSpace.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(
                    context, '/canli-mac/${notice.matchId}'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Maç Detayı', style: SwanType.caption(c.accent)),
              ),
            ),
          ],
        ],
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
          final access = ref.watch(swanAccessProvider);
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
                              Text('Bekleyen Resmi Sonuçlar',
                                  style: SwanType.h3(c.ink)),
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
                      loading: () => Center(
                          child: Padding(
                              padding: const EdgeInsets.all(SwanSpace.xl),
                              child: premiumLoading())),
                      error: (err, _) => premiumError(
                        context,
                        '$err',
                        onRetry: () =>
                            ref.invalidate(federationPendingResultsProvider(0)),
                      ),
                      data: (matches) {
                        if (matches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: SwanSpace.xl * 2),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 44, color: c.accent),
                                  const SizedBox(height: SwanSpace.sm),
                                  Text(
                                    'Bekleyen resmi tescil talebi bulunmuyor',
                                    style: SwanType.bodySm(c.ink,
                                        w: FontWeight.w700),
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
                                padding:
                                    const EdgeInsets.only(bottom: SwanSpace.md),
                                child: Container(
                                  padding: const EdgeInsets.all(SwanSpace.md),
                                  decoration: BoxDecoration(
                                    color: c.bg,
                                    borderRadius:
                                        BorderRadius.circular(SwanRadius.md),
                                    border: Border.all(color: c.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: SwanSpace.xs,
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              color: c.accent
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      SwanRadius.sm),
                                            ),
                                            child: Text(
                                              'V${match.version} Tescil',
                                              style: SwanType.caption(c.accent,
                                                  w: FontWeight.w700),
                                            ),
                                          ),
                                          const SizedBox(width: SwanSpace.xs),
                                          Text(
                                            liveSportName(match.sportCode),
                                            style: SwanType.caption(c.inkMuted),
                                          ),
                                          const Spacer(),
                                          if (match.startsAt != null)
                                            Text(liveStartTime(match.startsAt!),
                                                style: SwanType.caption(
                                                    c.inkMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: SwanSpace.sm),
                                      Text(
                                        '${match.homeName ?? "Ev Sahibi"} — ${match.awayName ?? "Deplasman"}',
                                        style: SwanType.bodySm(c.ink,
                                            w: FontWeight.w700),
                                      ),
                                      const SizedBox(height: SwanSpace.xs),
                                      Text(match.name,
                                          style: SwanType.caption(c.inkMuted)),
                                      if (match.location != null &&
                                          match.location!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(match.location!,
                                            style:
                                                SwanType.caption(c.inkMuted)),
                                      ],
                                      const SizedBox(height: SwanSpace.md),
                                      if (!access.canPublishResultFor(
                                        sportCode: match.sportCode,
                                        cityCode: match.cityCode,
                                      ))
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: SwanSpace.sm,
                                            vertical: SwanSpace.xs,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                c.danger.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                                SwanRadius.sm),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.lock_outline_rounded,
                                                  size: 14, color: c.danger),
                                              const SizedBox(
                                                  width: SwanSpace.xs),
                                              Expanded(
                                                child: Text(
                                                  'Bu branş için Sonuç Yayıncısı yetkiniz bulunmuyor (' +
                                                      liveSportName(
                                                          match.sportCode) +
                                                      ').',
                                                  style: SwanType.caption(
                                                      c.danger),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _showPublishResultDialog(
                                                    context, match),
                                            icon: const Icon(
                                                Icons.publish_rounded,
                                                size: 16),
                                            label: const Text(
                                                'Sonucu Tescil Et / Yayımla'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: c.accent,
                                              foregroundColor: c.onAccent,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          SwanRadius.md)),
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
    FederationPendingMatch match,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _PublishResultDialog(
        match: match,
        onSuccess: () {
          ref.invalidate(federationPendingResultsProvider(0));
          ref.invalidate(federationCenterOverviewProvider(_filter));
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

class _PublishResultDialog extends ConsumerStatefulWidget {
  const _PublishResultDialog({
    required this.match,
    required this.onSuccess,
  });

  final FederationPendingMatch match;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_PublishResultDialog> createState() =>
      _PublishResultDialogState();
}

class _PublishResultDialogState extends ConsumerState<_PublishResultDialog> {
  late final TextEditingController _reasonController;
  late final TextEditingController _homeScoreController;
  late final TextEditingController _awayScoreController;
  final List<({TextEditingController home, TextEditingController away})>
      _setControllers = [];

  bool _isSubmitting = false;

  bool get _isIndividualSport =>
      ['yuzme', 'atletizm', 'okculuk'].contains(widget.match.sportCode);

  bool get _isSetSport =>
      ['tenis', 'voleybol'].contains(widget.match.sportCode);

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController(
      text: widget.match.version == 0
          ? 'Hakem onaylı resmi maç sonucu tescili'
          : 'MHK tescil kararı',
    );
    _homeScoreController = TextEditingController();
    _awayScoreController = TextEditingController();

    if (_isSetSport) {
      _setControllers.add((
        home: TextEditingController(),
        away: TextEditingController(),
      ));
      _setControllers.add((
        home: TextEditingController(),
        away: TextEditingController(),
      ));
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    for (final s in _setControllers) {
      s.home.dispose();
      s.away.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    if (_isIndividualSport) {
      return AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanRadius.lg)),
        title: Text(
          'Masaüstü Konsolu Gerekli',
          style: SwanType.h3(c.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(SwanRadius.md),
                border: Border.all(color: c.line),
              ),
              child: Column(
                children: [
                  Icon(Icons.desktop_windows_rounded,
                      size: 40, color: c.accent),
                  const SizedBox(height: SwanSpace.sm),
                  Text(
                    '${liveSportName(widget.match.sportCode)} branşında resmi sonuçlar seri, kulvar ve sporcu dereceleri gerektirir.',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SwanSpace.xs),
                  Text(
                    'Lütfen bu müsabakayı Federasyon Yönetim Konsolu (Masaüstü Web) üzerinden tescil ediniz.',
                    style: SwanType.caption(c.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
            ),
            child: const Text('Anladım'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.lg)),
      title: Text('Resmi Sonuç Tescili (V${widget.match.version + 1})',
          style: SwanType.h3(c.ink)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.match.homeName ?? "Ev"} vs ${widget.match.awayName ?? "Deplasman"}',
              style: SwanType.bodySm(c.ink, w: FontWeight.w700),
            ),
            const SizedBox(height: SwanSpace.xs),
            Text(
              _isSetSport
                  ? 'Set Skorları (${liveSportName(widget.match.sportCode)})'
                  : 'Skor Girişi (${liveSportName(widget.match.sportCode)})',
              style: SwanType.caption(c.inkMuted),
            ),
            const SizedBox(height: SwanSpace.md),
            if (_isSetSport) ...[
              for (var i = 0; i < _setControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: SwanSpace.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text('${i + 1}. Set',
                            style: SwanType.caption(c.ink, w: FontWeight.w700)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _setControllers[i].home,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: widget.match.homeName ?? 'Ev',
                            filled: true,
                            fillColor: c.bg,
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md)),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: SwanSpace.sm),
                        child: Text(':',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _setControllers[i].away,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: widget.match.awayName ?? 'Dep',
                            filled: true,
                            fillColor: c.bg,
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  if (_setControllers.length < 5)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _setControllers.add((
                            home: TextEditingController(),
                            away: TextEditingController(),
                          ));
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Set Ekle'),
                    ),
                  if (_setControllers.length > 2)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          final removed = _setControllers.removeLast();
                          removed.home.dispose();
                          removed.away.dispose();
                        });
                      },
                      icon: const Icon(Icons.remove_rounded, size: 16),
                      label: const Text('Set Kaldır'),
                    ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _homeScoreController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: widget.match.homeName ?? 'Ev Skor',
                        filled: true,
                        fillColor: c.bg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md)),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: SwanSpace.sm),
                    child: Text(':',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _awayScoreController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: widget.match.awayName ?? 'Dep Skor',
                        filled: true,
                        fillColor: c.bg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: SwanSpace.md),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Tescil / Revizyon Gerekçesi',
                hintText: 'Örn: MHK onaylı resmi müsabaka tescili',
                filled: true,
                fillColor: c.bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text('İptal', style: SwanType.bodySm(c.inkMuted)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: c.accent,
            foregroundColor: c.onAccent,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Tescil Et'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tescil gerekçesi belirtin.')),
      );
      return;
    }

    final Map<String, dynamic> protocol;

    if (_isSetSport) {
      final sets = <Map<String, int>>[];
      for (var i = 0; i < _setControllers.length; i++) {
        final hs = int.tryParse(_setControllers[i].home.text.trim());
        final as = int.tryParse(_setControllers[i].away.text.trim());
        if (hs == null || as == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Lütfen ${i + 1}. set için geçerli skorlar girin.')),
          );
          return;
        }
        sets.add({'home': hs, 'away': as});
      }
      protocol = {'type': 'sets', 'sets': sets};
    } else {
      final hs = int.tryParse(_homeScoreController.text.trim());
      final as = int.tryParse(_awayScoreController.text.trim());
      if (hs == null || as == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lütfen geçerli sayısal skorlar girin.')),
        );
        return;
      }
      protocol = {'type': 'score', 'home': hs, 'away': as};
    }

    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(federationRecordsServiceProvider);
      if (service == null) throw StateError('Sunucu bağlantısı aktif değil');

      await service.publishResult(
        matchId: widget.match.id,
        protocol: protocol,
        reason: reason,
        expectedVersion: widget.match.version,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      widget.onSuccess();
      messenger.showSnackBar(
        const SnackBar(
            content:
                Text('Resmi sonuç başarıyla tescil edildi ve yayımlandı.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              e,
              defaultMessage:
                  'Tescil işlemi tamamlanamadı. Lütfen tekrar deneyin.',
            ),
          ),
        ),
      );
    }
  }
}

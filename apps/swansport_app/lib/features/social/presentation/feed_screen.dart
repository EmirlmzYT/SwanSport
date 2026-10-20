import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../network/presentation/guest_explore_screen.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/home/home_quick_access.dart';
import '../../../app/home/today_training_card.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'widgets/feed_entry.dart';
import 'widgets/follow_suggestions.dart';
import 'widgets/stitch_feed_widgets.dart';
import 'widgets/platform_notice.dart';
import '../../referee/referee_widgets.dart';
import '../../live_match/presentation/live_match_widgets.dart';

/// Ana Akış — kulüp gönderileri, duyurular ve haberler tek yerde (Instagram gibi).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _followingOnly = false;

  PlatformConfig? _lastPlatformConfig;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (mounted && ref.read(swanAccessProvider).hasAccount) {
        await ensureMyCommunities(ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(swanAccessProvider);
    // Profile/club resolution can lag behind Auth. SwanAccess.none during that
    // interval means no permissions yet, not that the session is a guest.
    final liveBackend = ref.watch(isSupabaseEnabledProvider);
    final session = liveBackend ? ref.watch(authSessionProvider) : null;
    if (session != null && session.hasError && !session.hasValue) {
      return SwanScaffold(
        backgroundColor: context.swan.bg,
        body: Center(
            child: TextButton(
          onPressed: () => ref.invalidate(authSessionProvider),
          child: const Text('Oturumu yeniden kontrol et'),
        )),
      );
    }
    if (session != null && !session.hasValue) {
      return SwanScaffold(backgroundColor: context.swan.bg);
    }
    final isGuest =
        session != null ? session.valueOrNull == null : !access.hasAccount;
    _lastPlatformConfig =
        ref.watch(platformConfigProvider).valueOrNull ?? _lastPlatformConfig;
    final config = _lastPlatformConfig;
    if (config?.maintenanceEnabled == true && !access.isPlatformAdmin) {
      return PlatformMaintenanceNotice(
          message:
              '${config!.maintenance['message'] ?? 'Kısa süreli bakım devam ediyor.'}',
          onRetry: () => ref.invalidate(platformConfigProvider));
    }
    final banner = config?.broadcastEnabled == true
        ? PlatformBroadcastBanner(
            key: ValueKey(jsonEncode([
              config!.broadcastAlert['severity'],
              config.broadcastAlert['title'],
              config.broadcastAlert['message']
            ])),
            alert: config.broadcastAlert)
        : null;
    if (isGuest) {
      if (banner == null) return const GuestExploreScreen();
      return Column(children: [
        SafeArea(
            bottom: false,
            child: Material(color: context.swan.bg, child: banner)),
        const Expanded(child: GuestExploreScreen())
      ]);
    }
    final c = context.swan;

    final activeFeed = _followingOnly ? feedProvider : discoverProvider;
    final async = ref.watch(activeFeed);
    return SwanScaffold(
      extendBody: true,
      scrollUnderHeader: true,
      backgroundColor: c.bg,
      appBar: StitchFeedTopBar(
        key: const Key('feed-floating-header'),
        followingOnly: _followingOnly,
        allLabel: 'Tümü (Keşfet)',
        followingLabel: 'Takip Ettiklerim',
        onFeedChanged: (value) {
          if (value != _followingOnly) setState(() => _followingOnly = value);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(feedProvider);
                ref.invalidate(discoverProvider);
                ref.invalidate(suggestionsProvider);
                ref.invalidate(newsProvider);
                ref.invalidate(announcementsProvider);
                ref.invalidate(platformConfigProvider);
                ref.invalidate(myRefereeMatchesProvider);
                ref.invalidate(refereeTodayMatchesProvider);
                ref.invalidate(publicLiveMatchesProvider);
                ref.invalidate(todayTrainingRsvpsProvider);
                await ref.read(activeFeed.future);
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: SwanHeaderSpacer()),
                  if (banner != null) SliverToBoxAdapter(child: banner),
                  const SliverToBoxAdapter(child: HomeQuickAccess()),
                  const SliverToBoxAdapter(child: HomeTodayTraining()),
                  const SliverToBoxAdapter(child: LiveMatchStrip()),
                  const SliverToBoxAdapter(
                      child: RefereeEntryCard(today: true)),
                  ...async.when(
                    loading: () => [
                      SliverToBoxAdapter(child: premiumCardLoading()),
                    ],
                    error: (e, _) => [
                      SliverToBoxAdapter(
                        child: premiumError(
                          context,
                          '$e',
                          onRetry: () => ref.invalidate(activeFeed),
                        ),
                      ),
                    ],
                    data: (posts) => _contentSlivers(context, ref, posts),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 132)),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    List<PostRow> posts,
  ) {
    final entries = _merge(ref, posts);

    if (entries.isNotEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            SwanSpace.lg,
            SwanSpace.md,
            SwanSpace.lg,
            0,
          ),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (_, index) => entries[index].build(),
          ),
        ),
      ];
    }

    if (!_followingOnly && ref.watch(newsProvider).isLoading) {
      return [
        SliverToBoxAdapter(child: premiumCardLoading()),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg,
          SwanSpace.md,
          SwanSpace.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: FollowSuggestions(
            onExplore: () => Navigator.pushNamed(context, '/kesfet'),
          ),
        ),
      ),
    ];
  }

  /// Gönderileri kulüp duyuruları ve yatay kaydırılabilir spor haberleri modülleriyle harmanlar.
  ///
  /// Haberler tüm akışı boğacak şekilde tek tek listelenmek yerine, 5'erli
  /// yatay kaydırılabilir kart modülleri halinde gönderilerin arasına periyodik serpiştirilir.
  List<FeedEntry> _merge(WidgetRef ref, List<PostRow> posts) {
    // Engellenen (ve engelleyen) kişilerin gönderileri akışta görünmez.
    final hidden = ref.watch(hiddenProfilesProvider).valueOrNull ?? const {};
    final postEntries = <FeedEntry>[
      for (final p in posts)
        if (!hidden.contains(p.authorId)) FeedEntry.post(p),
    ];

    final clubName = ref.watch(activeClubProvider).valueOrNull?.name;
    final anns = ref.watch(announcementsProvider).valueOrNull ?? const [];
    final annEntries = <FeedEntry>[
      for (final a in anns.take(10))
        FeedEntry.announcement(a, clubName: clubName),
    ];

    final socialEntries = [...postEntries, ...annEntries]
      ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

    // "Takip" sekmesinde genel spor haberleri yer almaz.
    if (_followingOnly) {
      return socialEntries;
    }

    final allNews = ref.watch(newsProvider).valueOrNull ?? const [];
    if (allNews.isEmpty) {
      return socialEntries;
    }

    // Haberleri en fazla 10 adetle sınırla ve 5'erli yatay gruplara böl
    final limitedNews = allNews.take(10).toList();
    final newsChunks = <List<NewsItem>>[];
    for (var i = 0; i < limitedNews.length; i += 5) {
      final chunk = limitedNews.sublist(i, math.min(i + 5, limitedNews.length));
      if (chunk.isNotEmpty) {
        newsChunks.add(chunk);
      }
    }

    if (socialEntries.isEmpty) {
      return [
        for (var i = 0; i < newsChunks.length; i++)
          FeedEntry.newsCarousel(
            newsChunks[i],
            carouselTitle:
                i == 0 ? 'Günün Spor Gündemi' : 'Öne Çıkan Başlıklar',
          ),
      ];
    }

    // Gönderilerin arasına her ~4 gönderide bir yatay haber modülü serpiştir
    final result = <FeedEntry>[];
    var chunkIdx = 0;
    const interval = 4;

    for (var i = 0; i < socialEntries.length; i++) {
      if (i > 0 && i % interval == 0 && chunkIdx < newsChunks.length) {
        result.add(FeedEntry.newsCarousel(
          newsChunks[chunkIdx],
          carouselTitle:
              chunkIdx == 0 ? 'Günün Spor Gündemi' : 'Öne Çıkan Başlıklar',
        ));
        chunkIdx++;
      }
      result.add(socialEntries[i]);
    }

    // Akış çok kısaysa ve henüz haber grubu gösterilmediyse sona ekle
    while (chunkIdx < newsChunks.length && chunkIdx < 2) {
      result.add(FeedEntry.newsCarousel(
        newsChunks[chunkIdx],
        carouselTitle:
            chunkIdx == 0 ? 'Günün Spor Gündemi' : 'Öne Çıkan Başlıklar',
      ));
      chunkIdx++;
    }

    return result;
  }
}

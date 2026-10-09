import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/stitch_components.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/today_tasks.dart';
import '../../attendance/presentation/attendance_queue_banner.dart';
import 'widgets/feed_entry.dart';
import 'widgets/follow_suggestions.dart';
import 'widgets/stitch_feed_widgets.dart';

/// Ana Akış — kulüp gönderileri, duyurular ve haberler tek yerde (Instagram gibi).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  bool _followingOnly = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ensureMyCommunities(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    final activeFeed = _followingOnly ? feedProvider : discoverProvider;
    final async = ref.watch(activeFeed);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
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
                await ref.read(activeFeed.future);
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Pinned Google Stitch üst bar (SwanSport Wordmark + Bildirimler + Mesajlar)
                  const SliverPersistentHeader(
                    pinned: true,
                    delegate: _StitchHeaderDelegate(),
                  ),
                  // Google Stitch Hikayeler Çubuğu (Stories Bar)
                  const SliverToBoxAdapter(
                    child: StitchStoriesBar(),
                  ),
                  const SliverToBoxAdapter(
                    child: TodayTasks(title: 'Bugün'),
                  ),
                  const SliverToBoxAdapter(child: AttendanceQueueBanner()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FeedModeDelegate(
                      extent: 42 + MediaQuery.textScalerOf(context).scale(12),
                      color: c.bg,
                      child: _FeedModeBar(
                        followingOnly: _followingOnly,
                        onChanged: (value) {
                          if (value == _followingOnly) return;
                          setState(() => _followingOnly = value);
                        },
                      ),
                    ),
                  ),

                  ...async.when(
                    loading: () => [
                      SliverToBoxAdapter(child: premiumCardLoading()),
                    ],
                    error: (e, _) => [
                      SliverToBoxAdapter(child: premiumError(context, '$e')),
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

  /// Gönderileri kulüp duyuruları ve spor haberleriyle harmanlar.
  ///
  /// Üçü de zaman sırasına göre tek listede akar; ana sayfa yalnızca
  /// gönderilerden ibaret kalmaz.
  List<FeedEntry> _merge(WidgetRef ref, List<PostRow> posts) {
    // Engellenen (ve engelleyen) kişilerin gönderileri akışta görünmez.
    final hidden = ref.watch(hiddenProfilesProvider).valueOrNull ?? const {};
    final entries = <FeedEntry>[
      for (final p in posts)
        if (!hidden.contains(p.authorId)) FeedEntry.post(p),
    ];

    final clubName = ref.watch(activeClubProvider).valueOrNull?.name;
    final anns = ref.watch(announcementsProvider).valueOrNull ?? const [];
    for (final a in anns.take(10)) {
      entries.add(FeedEntry.announcement(a, clubName: clubName));
    }

    // "Takip" yalnızca kişinin seçtiği hesapların gönderilerini ve kendi
    // kulüp duyurularını taşır. Genel spor haberleri "Sizin İçin" akışında.
    if (!_followingOnly) {
      final news = ref.watch(newsProvider).valueOrNull ?? const [];
      for (final n in news.take(15)) {
        entries.add(FeedEntry.news(n));
      }
    }

    entries.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return entries;
  }
}

/// Ana akış içindeki iki içerik modu. Keşfet sekmesinin yerine geçmez:
/// Keşfet spor modüllerini açar, burası yalnızca sosyal akışı süzer.
class _FeedModeBar extends StatelessWidget {
  const _FeedModeBar({
    required this.followingOnly,
    required this.onChanged,
  });

  final bool followingOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SwanSpace.lg,
        SwanSpace.sm,
        SwanSpace.lg,
        SwanSpace.xs,
      ),
      child: Row(
        children: [
          StitchFilterPill(
            label: 'Sizin İçin',
            isSelected: !followingOnly,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: SwanSpace.sm),
          StitchFilterPill(
            label: 'Takip',
            isSelected: followingOnly,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _StitchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StitchHeaderDelegate();

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return const StitchFeedTopBar();
  }

  @override
  bool shouldRebuild(covariant _StitchHeaderDelegate oldDelegate) => false;
}

class _FeedModeDelegate extends SliverPersistentHeaderDelegate {
  const _FeedModeDelegate({
    required this.child,
    required this.extent,
    required this.color,
  });
  final Widget child;
  final double extent;
  final Color color;
  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      Material(color: color, child: Center(child: child));
  @override
  bool shouldRebuild(covariant _FeedModeDelegate oldDelegate) =>
      child != oldDelegate.child ||
      extent != oldDelegate.extent ||
      color != oldDelegate.color;
}

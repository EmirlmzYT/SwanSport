import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/widgets/premium.dart';
import 'widgets/feed_entry.dart';
import 'widgets/follow_suggestions.dart';
import 'widgets/today_strip.dart';
import '../../../app/widgets/create_sheet.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';

/// Ana Akış — kulüp gönderileri, duyurular ve haberler tek yerde (Instagram gibi).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
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

    final async = ref.watch(feedProvider);

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
                ref.invalidate(suggestionsProvider);
                ref.invalidate(newsProvider);
                ref.invalidate(announcementsProvider);
                await ref.read(feedProvider.future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Bu alanın tamamı akışla beraber yukarı kayar. Ana Sayfa
                  // bir kontrol paneli gibi tepede sabit kalmaz.
                  SliverToBoxAdapter(
                    child: _FeedHeader(c: c),
                  ),
                  const SliverToBoxAdapter(child: TodayStrip()),
                  ...async.when(
                    loading: () => [
                      SliverToBoxAdapter(child: premiumLoading()),
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
              SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 0),
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
            SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 0),
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

    final news = ref.watch(newsProvider).valueOrNull ?? const [];
    for (final n in news.take(15)) {
      entries.add(FeedEntry.news(n));
    }

    entries.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return entries;
  }
}

/// Akışın üstü: merkezde açık akış adı, sağda tek hizada üç sade eylem.
/// Düğmelerde kutu, arka plan ve çerçeve yok; ikonlar header'ın içinde bir
/// araç çubuğu gibi durur. Rozet yalnız okunmamış olduğunda görünür.
class _FeedHeader extends StatelessWidget {
  const _FeedHeader({required this.c});

  final SwanPalette c;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(children: [
        // Marka solda kalınca sağdaki üç eylemle doğal bir denge kuruyor.
        Text('SwanSport', style: SwanType.wordmark(c.ink)),
        const Spacer(),
        _HeaderIcon(
          icon: Icons.add_box_outlined,
          tooltip: 'Oluştur',
          onTap: () => showCreateSheet(context),
        ),
        const _ActivitiesHeaderAction(),
        const _MessagesHeaderAction(),
      ]),
    );
  }
}

class _ActivitiesHeaderAction extends ConsumerWidget {
  const _ActivitiesHeaderAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _HeaderIcon(
        icon: Icons.favorite_border_rounded,
        badge: ref.watch(unreadNotificationsProvider).valueOrNull ?? 0,
        tooltip: 'Hareketler',
        onTap: () => Navigator.pushNamed(context, '/bildirimler'),
      );
}

class _MessagesHeaderAction extends ConsumerWidget {
  const _MessagesHeaderAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _HeaderIcon(
        icon: Icons.send_outlined,
        badge: ref.watch(unreadMessagesProvider).valueOrNull ?? 0,
        tooltip: 'Mesajlar',
        onTap: () => Navigator.pushNamed(context, '/mesajlar'),
      );
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Stack(clipBehavior: Clip.none, children: [
            Align(
              alignment: Alignment.center,
              child: Icon(icon, size: 24, color: c.ink),
            ),
            if (badge > 0)
              Positioned(
                top: 5,
                right: 2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    textAlign: TextAlign.center,
                    style: SwanType.caption(Colors.white, w: FontWeight.w800),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Ödenmemiş aidat şeridi.
///
/// Veli, borcunu ödemek için modül menüsünü karıştırmak zorunda kalmasın:
/// borç varsa ana ekranın tepesinde duruyor, yoksa hiç görünmüyor.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/create_sheet.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/today_tasks.dart';
import 'widgets/feed_entry.dart';
import 'widgets/follow_suggestions.dart';

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
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Bu alanın tamamı akışla beraber yukarı kayar. Ana Sayfa
                  // bir kontrol paneli gibi tepede sabit kalmaz.
                  SliverToBoxAdapter(
                    child: _FeedHeader(c: c),
                  ),
                  const SliverToBoxAdapter(
                    child: TodayTasks(title: 'Bugün'),
                  ),
                  SliverToBoxAdapter(
                    child: _FeedModeBar(
                      followingOnly: _followingOnly,
                      onChanged: (value) {
                        if (value == _followingOnly) return;
                        setState(() => _followingOnly = value);
                      },
                    ),
                  ),
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
    final c = context.swan;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.line),
          bottom: BorderSide(color: c.line),
        ),
      ),
      child: Row(
        children: [
          _FeedMode(
            label: 'Sizin İçin',
            active: !followingOnly,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: SwanSpace.xl),
          _FeedMode(
            label: 'Takip',
            active: followingOnly,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _FeedMode extends StatelessWidget {
  const _FeedMode({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final color = active ? c.ink : c.inkMuted;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SwanRadius.sm),
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Spacer(),
              Text(
                label,
                style: SwanType.bodySm(
                  color,
                  w: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: active ? 34 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      child: Row(
        children: [
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
        ],
      ),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
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
            ],
          ),
        ),
      ),
    );
  }
}

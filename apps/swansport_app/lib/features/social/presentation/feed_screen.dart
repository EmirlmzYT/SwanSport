import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../demo/demo_role.dart';
import 'post_composer_sheet.dart';
import 'widgets/feed_entry.dart';
import 'widgets/follow_suggestions.dart';
import 'widgets/today_strip.dart';
import '../../../app/widgets/inbox_actions.dart';
import '../../../app/widgets/today_tasks.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Ana Akış — kulüp gönderileri, duyurular ve haberler tek yerde (Instagram gibi).
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  int _tab = 0; // 0 = Takip, 1 = Keşfet

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ensureMyCommunities(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final async =
        _tab == 0 ? ref.watch(feedProvider) : ref.watch(discoverProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                // Üst bar — ana sayfa herkes için aynı, yalnızca hitap değişir
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SwanSport',
                              style: SwanType.h2(ink)),
                          const SizedBox(height: 2),
                          Text(
                            _greeting(
                              ref.watch(demoRoleProvider),
                              profile?.role,
                              profile?.firstName,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _openComposer(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [kTealBright, kTeal]),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const InboxActions(),
                  ]),
                ),

                // Rol etiketli öncelik kartları — "bugün ne yapmalıyım".
                // TodayStrip'in ÜSTÜNDE: şerit yaklaşan programı gösteriyor,
                // bu ise aksiyon bekleyen işi. Önce yapılacak iş, sonra
                // program.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const TodayTasks(),
                ),

                const TodayStrip(),

                // Arama çubuğu — dokununca arama ekranını açar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/ara'),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? SwanPalette.dark.surfaceAlt
                            : SwanPalette.light.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isDark
                                ? SwanPalette.dark.line
                                : SwanPalette.light.line),
                      ),
                      child: Row(children: [
                        Icon(Icons.search_rounded,
                            size: 20, color: SwanColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Kulüp, antrenör veya sporcu ara…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.bodySm(SwanColors.textSecondary)),
                        ),
                      ]),
                    ),
                  ),
                ),

                // Sekmeler
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SwanSegmentedTabs(
                    labels: const ['Takip', 'Keşfet'],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(feedProvider);
                      ref.invalidate(discoverProvider);
                      ref.invalidate(suggestionsProvider);
                      ref.invalidate(newsProvider);
                      ref.invalidate(announcementsProvider);
                      await ref.read(_tab == 0
                          ? feedProvider.future
                          : discoverProvider.future);
                    },
                    child: async.when(
                      loading: () => ListView(children: [premiumLoading()]),
                      error: (e, _) =>
                          ListView(children: [premiumError(context, '$e')]),
                      data: (posts) {
                        if (posts.isEmpty) {
                          // Gönderi yoksa bile duyuru/haber varsa akış dolu.
                          final entries = _merge(ref, const []);
                          if (entries.isNotEmpty) {
                            return ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 132),
                              itemCount: entries.length + 1,
                              itemBuilder: (_, i) => i == 0
                                  ? Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: FollowSuggestions(
                                        onExplore: () =>
                                            setState(() => _tab = 1),
                                      ),
                                    )
                                  : entries[i - 1].build(),
                            );
                          }
                          // Takip sekmesi boşsa: her şeyi göstermek yerine
                          // kimi takip edebileceğini öner.
                          if (_tab == 0) {
                            return ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 132),
                              children: [
                                FollowSuggestions(
                                  onExplore: () => setState(() => _tab = 1),
                                ),
                              ],
                            );
                          }
                          return ListView(
                            padding: const EdgeInsets.only(top: 30),
                            children: [
                              premiumEmpty(
                                context,
                                icon: Icons.dynamic_feed_rounded,
                                title: 'Henüz gönderi yok',
                                subtitle: 'İlk gönderiyi sen paylaş.',
                                actionLabel: 'Gönderi Paylaş',
                                onAction: () => _openComposer(context),
                              ),
                            ],
                          );
                        }
                        final entries = _merge(ref, posts);
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 132),
                          itemCount: entries.length,
                          itemBuilder: (_, i) => entries[i].build(),
                        );
                      },
                    ),
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

  /// Ana sayfa herkes için aynıdır; yalnızca bu hitap role göre değişir.
  /// Demo rolü aktifse onu, değilse gerçek kulüp üyeliği rolünü esas alır.
  String _greeting(DemoRole? demo, String? role, String? name) {
    final n = (name == null || name.trim().isEmpty) ? null : name.trim();
    final suffix = n == null ? '' : ', $n';

    if (demo != null) {
      return switch (demo) {
        DemoRole.platformAdmin => 'Platform yönetimi$suffix',
        DemoRole.clubAdmin => 'İyi çalışmalar$suffix',
        DemoRole.coach5 ||
        DemoRole.coach4 ||
        DemoRole.coach3 ||
        DemoRole.coach2 ||
        DemoRole.coach1 =>
          'İyi antrenmanlar$suffix',
        DemoRole.athleteLicensed ||
        DemoRole.athleteIndividual =>
          'Bugün de formda kal$suffix',
        DemoRole.guardian => 'Hoş geldin$suffix',
        DemoRole.member => 'Hoş geldin$suffix',
      };
    }

    return switch (role) {
      'club_admin' => 'İyi çalışmalar$suffix',
      'coach' => 'İyi antrenmanlar$suffix',
      'athlete' => 'Bugün de formda kal$suffix',
      'parent' => 'Hoş geldin$suffix',
      _ => 'Hoş geldin$suffix',
    };
  }

  Future<void> _openComposer(BuildContext context) async {
    final created = await showPostComposer(context);
    if (created == true) {
      ref.invalidate(feedProvider);
      ref.invalidate(discoverProvider);
    }
  }

}

/// Ödenmemiş aidat şeridi.
///
/// Veli, borcunu ödemek için modül menüsünü karıştırmak zorunda kalmasın:
/// borç varsa ana ekranın tepesinde duruyor, yoksa hiç görünmüyor.

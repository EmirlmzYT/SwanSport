import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_app/app/widgets/swan_floating_header.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_chrome.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/inbox_actions.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'guest_explore_screen.dart';

/// Spor ağındaki gerçek kişileri, kulüpleri ve fırsatları keşfetme ekranı.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  static const _clubFilter = DiscoverFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(swanAccessProvider).hasAccount) {
      return const GuestExploreScreen();
    }
    final c = context.swan;
    final announcements = ref.watch(announcementsProvider);
    final pinned = announcements.valueOrNull
        ?.where((item) => item.pinned)
        .cast<AnnouncementRow?>()
        .firstOrNull;
    final shortcuts = <_ExploreLink>[
      const _ExploreLink(Icons.shield_outlined, 'Kulüp bul',
          'Branşına uygun kulüpleri keşfet', '/kulupler'),
      if (ref.watch(featureEnabledProvider(FeatureFlags.coachDiscovery)))
        const _ExploreLink(Icons.sports_rounded, 'Antrenör bul',
            'Onaylı antrenörleri incele', '/antrenor-bul'),
      if (ref.watch(featureEnabledProvider(FeatureFlags.courts)))
        const _ExploreLink(Icons.stadium_outlined, 'Saha bul',
            'Saha ve tesisleri görüntüle', '/kortlar'),
      if (ref.watch(featureEnabledProvider(FeatureFlags.partnerSearch)))
        const _ExploreLink(Icons.people_outline_rounded, 'Partner bul',
            'Birlikte spor yapacak birini bul', '/partner-ara'),
    ];

    return SwanScaffold(
      extendBody: true,
      scrollUnderHeader: true,
      backgroundColor: c.bg,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(SwanChrome.headerHeight),
        child: _ExploreHeader(),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const Key('explore-scroll-view'),
          slivers: [
            const SliverToBoxAdapter(child: SwanHeaderSpacer()),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, SwanSpace.xl * 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SearchEntry(
                            onTap: () => Navigator.pushNamed(context, '/ara')),
                        if (pinned != null) ...[
                          const SizedBox(height: SwanSpace.md),
                          _PinnedAnnouncement(
                            announcement: pinned,
                            onTap: () =>
                                Navigator.pushNamed(context, '/announcements'),
                          ),
                        ],
                        const SizedBox(height: SwanSpace.xl),
                        Text('Keşfetmeye başla', style: SwanType.h2(c.ink)),
                        const SizedBox(height: SwanSpace.xs),
                        Text('Aradığın spor bağlantısına doğrudan ulaş.',
                            style: SwanType.bodySm(c.inkMuted)),
                        const SizedBox(height: SwanSpace.md),
                        _ShortcutGrid(links: shortcuts),
                        const SizedBox(height: SwanSpace.xl * 2),
                        _ClubSection(
                          value: ref.watch(discoverClubsProvider(_clubFilter)),
                          onRetry: () => ref
                              .invalidate(discoverClubsProvider(_clubFilter)),
                        ),
                        _PeopleSection(
                          value: ref.watch(suggestionsProvider),
                          onRetry: () => ref.invalidate(suggestionsProvider),
                        ),
                        _OrganizationSection(
                          value: ref.watch(organizationsProvider('')),
                          onRetry: () =>
                              ref.invalidate(organizationsProvider('')),
                        ),
                        _AllCategories(links: _categoryLinks(ref)),
                        _AnnouncementSection(value: announcements),
                        _ClubPostSection(
                          value: ref.watch(discoverProvider),
                          hiddenProfiles:
                              ref.watch(hiddenProfilesProvider).valueOrNull ??
                                  const <String>{},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  List<_ExploreLink> _categoryLinks(WidgetRef ref) => [
        const _ExploreLink(Icons.emoji_events_outlined, 'Organizasyonlar',
            'Turnuva, lig ve etkinlikler', '/organizasyonlar'),
        const _ExploreLink(Icons.forum_outlined, 'Topluluklar',
            'Spor topluluklarına katıl', '/topluluklar'),
        const _ExploreLink(Icons.campaign_outlined, 'İlanlar',
            'Seçme ve spor ilanları', '/ilanlar'),
        const _ExploreLink(Icons.verified_outlined, 'Federasyon',
            'Resmi takvim ve sonuçlar', '/federasyon-merkezi'),
        if (ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub)))
          const _ExploreLink(Icons.scoreboard_outlined, 'Canlı skor',
              'Devam eden resmi maçlar', '/canli-skor'),
        if (ref.watch(featureEnabledProvider(FeatureFlags.marketplace)))
          const _ExploreLink(Icons.storefront_outlined, 'Pazaryeri',
              'Spor ekipmanları', '/pazaryeri'),
      ];
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader();
  @override
  Widget build(BuildContext context) => SwanFloatingHeader(
        title: Text('Keşfet', style: SwanType.h2(context.swan.ink)),
        actions: const [InboxActions(spacing: 0)],
      );
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Semantics(
      button: true,
      label: 'Kulüp, antrenör veya sporcu ara',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        child: InkWell(
          key: const Key('explore-search-entry'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Icon(Icons.search_rounded, color: c.accent),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kimi veya neyi arıyorsun?',
                        style: SwanType.body(c.ink, w: FontWeight.w700)),
                    const SizedBox(height: SwanSpace.xs),
                    Text('Kulüp, antrenör veya sporcu ara',
                        style: SwanType.bodySm(c.inkMuted)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: c.inkMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PinnedAnnouncement extends StatelessWidget {
  const _PinnedAnnouncement({required this.announcement, required this.onTap});
  final AnnouncementRow announcement;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Material(
      color: c.warning.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.md),
          child: Row(children: [
            Icon(Icons.push_pin_outlined, color: c.warning, size: 20),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: Text(announcement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
            ),
            Icon(Icons.chevron_right_rounded, color: c.inkMuted),
          ]),
        ),
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({required this.links});
  final List<_ExploreLink> links;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final columns = scale >= 1.6 || constraints.maxWidth < 340
              ? 1
              : constraints.maxWidth >= 760
                  ? 4
                  : 2;
          final width =
              (constraints.maxWidth - SwanSpace.md * (columns - 1)) / columns;
          return Wrap(
            spacing: SwanSpace.md,
            runSpacing: SwanSpace.md,
            children: [
              for (final link in links)
                SizedBox(width: width, child: _ShortcutCard(link: link)),
            ],
          );
        },
      );
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.link});
  final _ExploreLink link;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Semantics(
      button: true,
      label: '${link.title}. ${link.subtitle}',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, link.route),
          borderRadius: BorderRadius.circular(SwanRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 116),
            child: Padding(
              padding: const EdgeInsets.all(SwanSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(link.icon, color: c.accent, size: 26),
                  const SizedBox(height: SwanSpace.md),
                  Text(link.title,
                      style: SwanType.body(c.ink, w: FontWeight.w700)),
                  const SizedBox(height: SwanSpace.xs),
                  Text(link.subtitle, style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubSection extends StatelessWidget {
  const _ClubSection({required this.value, required this.onRetry});
  final AsyncValue<List<DiscoveredClub>> value;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _AsyncSection<DiscoveredClub>(
        title: 'Keşfedilecek kulüpler',
        value: value,
        onRetry: onRetry,
        onShowAll: () => Navigator.pushNamed(context, '/kulupler'),
        itemBuilder: (context, club) => _DiscoveryCard(
          icon: Icons.shield_outlined,
          title: club.name,
          subtitle: [club.sportName, club.where]
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .join(' • '),
          badge: club.isVerified ? 'Doğrulanmış' : null,
          onTap: () =>
              Navigator.pushNamed(context, '/kulup-profil', arguments: club.id),
        ),
      );
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({required this.value, required this.onRetry});
  final AsyncValue<List<SuggestionRow>> value;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _AsyncSection<SuggestionRow>(
        title: 'Sporcular ve antrenörler',
        value: value
            .whenData((items) => items.where((item) => !item.isClub).toList()),
        onRetry: onRetry,
        onShowAll: () => Navigator.pushNamed(context, '/ara'),
        itemBuilder: (context, person) => _DiscoveryCard(
          icon: person.kind == 'coach'
              ? Icons.sports_rounded
              : Icons.person_outline_rounded,
          title: person.name,
          subtitle: person.subtitle ??
              (person.kind == 'coach' ? 'Antrenör' : 'Sporcu'),
          badge: person.kind == 'coach' ? 'Antrenör' : null,
          onTap: () =>
              Navigator.pushNamed(context, '/profil', arguments: person.id),
        ),
      );
}

class _OrganizationSection extends StatelessWidget {
  const _OrganizationSection({required this.value, required this.onRetry});
  final AsyncValue<List<Organization>> value;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _AsyncSection<Organization>(
      title: 'Yaklaşan organizasyonlar',
      value: value.whenData((items) => items
          .where((item) =>
              !item.isFinished &&
              item.startsOn != null &&
              !item.startsOn!.isBefore(today))
          .toList()
        ..sort((a, b) => a.startsOn!.compareTo(b.startsOn!))),
      onRetry: onRetry,
      onShowAll: () => Navigator.pushNamed(context, '/organizasyonlar'),
      itemBuilder: (context, item) => _DiscoveryCard(
        icon: Icons.emoji_events_outlined,
        title: item.name,
        subtitle: [_date(item.startsOn!), item.sportName, item.cityName]
            .whereType<String>()
            .where((text) => text.isNotEmpty)
            .join(' • '),
        badge: item.kindLabel,
        onTap: () => Navigator.pushNamed(context, '/organizasyonlar'),
      ),
    );
  }

  String _date(DateTime date) {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _AsyncSection<T> extends StatelessWidget {
  const _AsyncSection({
    required this.title,
    required this.value,
    required this.onRetry,
    required this.itemBuilder,
    required this.onShowAll,
  });
  final String title;
  final AsyncValue<List<T>> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext, T) itemBuilder;
  final VoidCallback onShowAll;
  @override
  Widget build(BuildContext context) => value.when(
        loading: () => _LoadingSection(title: title),
        error: (_, __) => _SectionError(title: title, onRetry: onRetry),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return _SectionShell(
            title: title,
            onShowAll: onShowAll,
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth >= 760
                  ? (constraints.maxWidth - SwanSpace.md) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: SwanSpace.md,
                runSpacing: SwanSpace.sm,
                children: [
                  for (final item in items.take(4))
                    SizedBox(width: width, child: itemBuilder(context, item)),
                ],
              );
            }),
          );
        },
      );
}

class _SectionShell extends StatelessWidget {
  const _SectionShell(
      {required this.title, required this.child, this.onShowAll});
  final String title;
  final Widget child;
  final VoidCallback? onShowAll;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.xl * 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: SwanType.h2(c.ink))),
          if (onShowAll != null)
            TextButton(onPressed: onShowAll, child: const Text('Tümü')),
        ]),
        const SizedBox(height: SwanSpace.sm),
        child,
      ]),
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.md),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(icon, color: c.accent),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: SwanSpace.sm),
                      Text(badge!, style: SwanType.caption(c.accent)),
                    ],
                  ]),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: SwanSpace.xs),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.inkMuted),
          ]),
        ),
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => _SectionShell(
        title: title,
        child: Semantics(
          label: '$title yükleniyor',
          child: Column(
            children: List.generate(
              2,
              (_) => Container(
                height: 70,
                margin: const EdgeInsets.only(bottom: SwanSpace.sm),
                decoration: BoxDecoration(
                  color: context.swan.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
              ),
            ),
          ),
        ),
      );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.title, required this.onRetry});
  final String title;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => _SectionShell(
        title: title,
        child: Row(children: [
          Icon(Icons.error_outline_rounded, color: context.swan.warning),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Text('Bu bölüm şu anda yüklenemedi.',
                style: SwanType.bodySm(context.swan.inkMuted)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ]),
      );
}

class _AllCategories extends StatelessWidget {
  const _AllCategories({required this.links});
  final List<_ExploreLink> links;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.xl * 2),
      child: Material(
        color: c.accent.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: InkWell(
          key: const Key('all-categories-button'),
          onTap: () => _show(context),
          borderRadius: BorderRadius.circular(SwanRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Row(children: [
              Icon(Icons.grid_view_rounded, color: c.accent),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tüm kategoriler',
                        style: SwanType.body(c.ink, w: FontWeight.w700)),
                    const SizedBox(height: SwanSpace.xs),
                    Text('Organizasyon, topluluk, ilan ve diğer alanlar',
                        style: SwanType.bodySm(c.inkMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkMuted),
            ]),
          ),
        ),
      ),
    );
  }

  void _show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tüm kategoriler',
                    style: SwanType.h2(sheetContext.swan.ink)),
                const SizedBox(height: SwanSpace.md),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: links.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final link = links[index];
                      return ListTile(
                        minTileHeight: 64,
                        leading: Icon(link.icon),
                        title: Text(link.title),
                        subtitle: Text(link.subtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.pushNamed(context, link.route);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _AnnouncementSection extends StatelessWidget {
  const _AnnouncementSection({required this.value});
  final AsyncValue<List<AnnouncementRow>> value;
  @override
  Widget build(BuildContext context) {
    final items =
        value.valueOrNull?.where((item) => !item.pinned).take(2).toList() ??
            const <AnnouncementRow>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return _SectionShell(
      title: 'Kulüp duyuruları',
      onShowAll: () => Navigator.pushNamed(context, '/announcements'),
      child: Column(
        children: [
          for (final item in items)
            _DiscoveryCard(
              icon: Icons.campaign_outlined,
              title: item.title,
              subtitle: item.body,
              onTap: () => Navigator.pushNamed(context, '/announcements'),
            ),
        ],
      ),
    );
  }
}

class _ClubPostSection extends StatelessWidget {
  const _ClubPostSection({required this.value, required this.hiddenProfiles});
  final AsyncValue<List<PostRow>> value;
  final Set<String> hiddenProfiles;
  @override
  Widget build(BuildContext context) {
    final posts = value.valueOrNull
            ?.where((post) =>
                post.isClubPost && !hiddenProfiles.contains(post.authorId))
            .take(2)
            .toList() ??
        const <PostRow>[];
    if (posts.isEmpty) return const SizedBox.shrink();
    return _SectionShell(
      title: 'Kulüplerden paylaşımlar',
      child: Column(
        children: [for (final post in posts) _ClubPostCard(post: post)],
      ),
    );
  }
}

class _ClubPostCard extends StatelessWidget {
  const _ClubPostCard({required this.post});
  final PostRow post;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(post.displayName,
            style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
        const SizedBox(height: SwanSpace.sm),
        Text(post.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: SwanType.bodySm(c.inkMuted)),
      ]),
    );
  }
}

class _ExploreLink {
  const _ExploreLink(this.icon, this.title, this.subtitle, this.route);
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

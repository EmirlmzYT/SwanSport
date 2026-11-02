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
import '../../../app/widgets/stitch_components.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'guest_explore_screen.dart';

/// Sosyal uygulamadaki araçlara sade ve doğrudan erişim noktası.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(swanAccessProvider).hasAccount) {
      return const GuestExploreScreen();
    }

    final c = context.swan;
    final sportsTools = <_ExploreTool>[
      _ExploreTool(
        icon: Icons.stadium_rounded,
        title: 'Tesis bul',
        subtitle: 'Saha ve müsaitlik',
        onTap: () => Navigator.pushNamed(context, '/kortlar'),
      ),
      _ExploreTool(
        icon: Icons.handshake_rounded,
        title: 'Partner bul',
        subtitle: 'Birlikte oynayacak biri',
        onTap: () => Navigator.pushNamed(context, '/partner-ara'),
      ),
      _ExploreTool(
        icon: Icons.emoji_events_rounded,
        title: 'Organizasyonlar',
        subtitle: 'Turnuva ve etkinlik',
        color: c.warning,
        onTap: () => Navigator.pushNamed(context, '/organizasyonlar'),
      ),
      _ExploreTool(
        icon: Icons.military_tech_rounded,
        title: 'Antrenmanlarım',
        subtitle: 'Geçmiş ve program',
        onTap: () => Navigator.pushNamed(context, '/antrenmanlarim'),
      ),
    ];
    final communityTools = <_ExploreTool>[
      _ExploreTool(
        icon: Icons.travel_explore_rounded,
        title: 'Kulüpler',
        subtitle: 'Yakınındaki kulüpler',
        onTap: () => Navigator.pushNamed(context, '/kulupler'),
      ),
      _ExploreTool(
        icon: Icons.forum_rounded,
        title: 'Topluluklar',
        subtitle: 'Spor odaları',
        onTap: () => Navigator.pushNamed(context, '/topluluklar'),
      ),
      _ExploreTool(
        icon: Icons.campaign_rounded,
        title: 'İlanlar',
        subtitle: 'Seçme ve duyurular',
        onTap: () => Navigator.pushNamed(context, '/ilanlar'),
      ),
      if (ref.watch(featureEnabledProvider('coach_discovery')))
        _ExploreTool(
          icon: Icons.sports_rounded,
          title: 'Antrenör bul',
          subtitle: 'Onaylı eğitmenler',
          onTap: () => Navigator.pushNamed(context, '/antrenor-bul'),
        ),
    ];
    final followTools = <_ExploreTool>[
      _ExploreTool(
        icon: Icons.verified_rounded,
        title: 'Federasyon',
        subtitle: 'Takvim ve sonuçlar',
        onTap: () => Navigator.pushNamed(context, '/federasyon-merkezi'),
      ),
      if (ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub)))
        _ExploreTool(
          icon: Icons.scoreboard_outlined,
          title: 'Canlı skor',
          subtitle: 'Resmi maçlar',
          color: c.ink,
          onTap: () => Navigator.pushNamed(context, '/canli-skor'),
        ),
      if (ref.watch(featureEnabledProvider(FeatureFlags.marketplace)))
        _ExploreTool(
          icon: Icons.storefront_rounded,
          title: 'Pazaryeri',
          subtitle: 'Spor ekipmanları',
          color: c.warning,
          onTap: () => Navigator.pushNamed(context, '/pazaryeri'),
        ),
    ];

    return SwanScaffold(
      extendBody: true,
      scrollUnderHeader: true,
      backgroundColor: c.bg,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(SwanChrome.headerHeight),
        child: _StitchExploreHeader(),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, SwanSpace.xl * 5),
              children: [
                const SwanHeaderSpacer(),
                const SizedBox(height: SwanSpace.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                  child: _ExploreSearchPanel(
                    onSearch: () => Navigator.pushNamed(context, '/ara'),
                  ),
                ),
                const SizedBox(height: SwanSpace.xl),
                _ExploreToolSection(title: 'Spor yap', tools: sportsTools),
                const SizedBox(height: SwanSpace.xl),
                _ExploreToolSection(title: 'Topluluk', tools: communityTools),
                const SizedBox(height: SwanSpace.xl),
                _ExploreToolSection(title: 'Takip et', tools: followTools),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

class _ExploreSearchPanel extends StatelessWidget {
  const _ExploreSearchPanel({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.accent.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ne arıyorsun?', style: SwanType.h2(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          Text(
            'Kulüp, antrenör, branş veya şehir ara.',
            style: SwanType.bodySm(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.md),
          Material(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            child: InkWell(
              key: const Key('explore-search-entry'),
              onTap: onSearch,
              borderRadius: BorderRadius.circular(SwanRadius.lg),
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SwanRadius.lg),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: c.accent),
                    const SizedBox(width: SwanSpace.sm),
                    Expanded(
                      child: Text(
                        'SwanSport’ta ara',
                        style: SwanType.body(c.inkMuted),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: c.inkMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreToolSection extends StatelessWidget {
  const _ExploreToolSection({required this.title, required this.tools});

  final String title;
  final List<_ExploreTool> tools;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StitchSectionTitle(title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - SwanSpace.sm) / 2;
              return Wrap(
                spacing: SwanSpace.sm,
                runSpacing: SwanSpace.sm,
                children: [
                  for (final tool in tools)
                    SizedBox(
                      width: itemWidth,
                      child: _ModuleGridCard(tool: tool),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExploreTool {
  const _ExploreTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
}

class _StitchExploreHeader extends ConsumerWidget {
  const _StitchExploreHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwanFloatingHeader(
      title: Text('Keşfet', style: SwanType.h2(context.swan.ink)),
      actions: const [InboxActions(spacing: 0)],
    );
  }
}

class _ModuleGridCard extends StatelessWidget {
  const _ModuleGridCard({required this.tool});

  final _ExploreTool tool;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final color = tool.color ?? c.accent;
    return Semantics(
      button: true,
      label: '${tool.title}, ${tool.subtitle}',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: InkWell(
          onTap: tool.onTap,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          child: Container(
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.sm),
            decoration: BoxDecoration(
              border: Border.all(color: c.line),
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Icon(tool.icon, color: color, size: 20),
                ),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tool.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tool.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

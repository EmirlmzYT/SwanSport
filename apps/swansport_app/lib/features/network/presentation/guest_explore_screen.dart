import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../../app/widgets/swan_module_app_bar.dart';
import '../../../app/widgets/swan_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../calendar/presentation/screens/schedule_calendar_screen.dart';
import '../../social/presentation/widgets/feed_entry.dart';
import '../../live_match/presentation/live_match_widgets.dart';

/// Public discovery constructs only providers intended for anonymous reads.
class GuestExploreScreen extends ConsumerWidget {
  const GuestExploreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    return SwanScaffold(
      backgroundColor: context.swan.bg,
      appBar: swanModuleAppBar(context, title: 'SwanSport · Keşfet'),
      bottomNavigationBar: const SwanBottomNav(),
      body: ListView(
        padding: const EdgeInsets.all(SwanSpace.lg),
        children: [
          Text('Misafir olarak keşfet', style: SwanType.h2(c.ink)),
          const SizedBox(height: SwanSpace.sm),
          Text(
              'Haberleri, tesisleri ve yayımlanmış federasyon programlarını hesapsız inceleyebilirsin.',
              style: SwanType.bodySm(c.inkMuted)),
          const SizedBox(height: SwanSpace.lg),
          const LiveMatchStrip(),
          if(ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub))) SwanActionCard(
            icon: Icons.scoreboard_outlined,
            title: 'Canlı Skor Merkezi',
            onTap:()=>Navigator.pushNamed(context,'/canli-skor'),
          ),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/auth'),
            child: const Text('Giriş Yap / Kayıt Ol'),
          ),
          const SizedBox(height: SwanSpace.lg),
          SwanActionCard(
            icon: Icons.stadium_outlined,
            title: 'Kortlar ve sahalar',
            subtitle: 'Tesisleri ve müsait saatleri incele',
            onTap: () => Navigator.pushNamed(context, '/kortlar'),
          ),
          SwanActionCard(
            icon: Icons.event_outlined,
            title: 'Federasyon Faaliyet Takvimi',
            onTap: () => Navigator.pushNamed(context, '/federasyon-takvimi'),
          ),
          SwanActionCard(
            icon: Icons.sports_tennis_outlined,
            title: 'Partner Bul',
            subtitle: 'Halka açık oyun ilanlarına göz at',
            onTap: () => Navigator.pushNamed(context, '/partner-ara'),
          ),
          const SizedBox(height: SwanSpace.xl),
          Text('Spor haberleri', style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.md),
          ref.watch(newsProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => TextButton(
                  onPressed: () => ref.invalidate(newsProvider),
                  child: const Text('Haberler yüklenemedi. Yeniden dene'),
                ),
                data: (items) => items.isEmpty
                    ? Text('Henüz haber yok.',
                        style: SwanType.bodySm(c.inkMuted))
                    : Column(children: [
                        for (final item in items) NewsCard(item: item)
                      ]),
              ),
        ],
      ),
    );
  }
}

/// Preserve the existing public deep link using the shared calendar experience.
class PublicSportCalendarScreen extends StatelessWidget {
  const PublicSportCalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => const ScheduleCalendarScreen(
      initialType: CalendarEventType.officialFederation);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../social/presentation/widgets/feed_entry.dart';

/// Public discovery constructs only providers intended for anonymous reads.
class GuestExploreScreen extends ConsumerWidget {
  const GuestExploreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SwanSport · Keşfet'),
      ),
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
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/auth'),
            child: const Text('Giriş Yap / Kayıt Ol'),
          ),
          const SizedBox(height: SwanSpace.lg),
          ListTile(
            leading: const Icon(Icons.stadium_outlined),
            title: const Text('Kortlar ve sahalar'),
            subtitle: const Text('Tesisleri ve müsait saatleri incele'),
            onTap: () => Navigator.pushNamed(context, '/kortlar'),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Federasyon Faaliyet Takvimi'),
            onTap: () => Navigator.pushNamed(context, '/federasyon-takvimi'),
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

class PublicSportCalendarScreen extends ConsumerWidget {
  const PublicSportCalendarScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    return Scaffold(
      appBar: AppBar(title: const Text('Federasyon Faaliyet Takvimi')),
      body: ref.watch(publicSportProgramsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: TextButton(
              onPressed: () => ref.invalidate(publicSportProgramsProvider),
              child: const Text('Programlar yüklenemedi. Yeniden dene'),
            )),
            data: (programs) => programs.isEmpty
                ? Center(
                    child: Text('Henüz yayımlanmış program yok.',
                        style: SwanType.bodySm(c.inkMuted)))
                : ListView(children: [
                    for (final p in programs)
                      ExpansionTile(
                        title: Text(p.name, style: SwanType.h3(c.ink)),
                        subtitle: Text(
                            '${p.sportCode} · ${p.cityCode} · ${p.seasonLabel}\n${p.startsOn} – ${p.endsOn}'),
                        children: [_PublicFixture(orgId: p.id)],
                      )
                  ]),
          ),
    );
  }
}

class _PublicFixture extends ConsumerWidget {
  const _PublicFixture({required this.orgId});
  final String orgId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(publicProgramFixtureProvider(orgId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => TextButton(
              onPressed: () =>
                  ref.invalidate(publicProgramFixtureProvider(orgId)),
              child: const Text('Fikstür yüklenemedi. Yeniden dene'),
            ),
            data: (matches) => matches.isEmpty
                ? const ListTile(title: Text('Henüz maç yok.'))
                : Column(children: [
                    for (final m in matches)
                      ListTile(
                        title: Text(
                            '${m.homeName ?? "Kulüp"} – ${m.awayName ?? "Kulüp"}'),
                        subtitle: Text(
                            '${m.startsAt.toUtc().add(const Duration(hours: 3)).toString().substring(0, 16)} · ${m.location ?? "Yer belirtilmedi"}'),
                      )
                  ]),
          );
}

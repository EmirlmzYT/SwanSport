import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import '../theme/console_theme.dart';

/// The duty screen owns assignment responses and match actions.
class ConsoleTodayReferee extends ConsumerWidget {
  const ConsoleTodayReferee({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duties = ref.watch(myRefereeMatchesProvider(null));
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bugün yapacaklarım',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: ConsoleDensity.sm),
        const Text(
            'Görev kayıtların · Liste yalnız bugüne ait müsabakalarla sınırlı değildir.'),
        const SizedBox(height: ConsoleDensity.md),
        duties.when(
          loading: () => const Text('Hakem görevleri yükleniyor…'),
          error: (_, __) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hakem görevleri alınamadı.'),
            TextButton(
                onPressed: () => ref.invalidate(myRefereeMatchesProvider(null)),
                child: const Text('Tekrar dene')),
          ]),
          data: (matches) {
            final ordered = [...matches]..sort((a, b) {
                if (a.startsAt == null) return b.startsAt == null ? 0 : 1;
                if (b.startsAt == null) return -1;
                return a.startsAt!.compareTo(b.startsAt!);
              });
            if (ordered.isEmpty)
              return const Text('Listelenecek hakem görevin yok.');
            return Column(children: [
              for (final match in ordered)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sports_score_outlined),
                    title: Text(
                        '${match.homeClubName ?? 'Ev sahibi'} — ${match.awayClubName ?? 'Deplasman'}'),
                    subtitle: Text(
                        '${match.sportCode.toUpperCase()} · ${match.startsAt == null ? 'Tarih belirtilmedi' : fmtDate(match.startsAt!)}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/hakem-gorevleri')),
            ]);
          },
        ),
      ]),
    ));
  }
}

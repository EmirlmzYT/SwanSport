import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

/// Ana Sayfa'nın "Bugün" şeridi.
///
/// Brief §4: ana sayfa *"kesinlikle klasik admin dashboard gibi
/// görünmemeli"* — bilgileri üst üste büyük kartlara dizmek yerine
/// **hafif, yatay kaydırılabilir** içerikler.
///
/// Yeni sorgu yazılmadı: `eventsProvider` ve `myFeesProvider` zaten vardı,
/// bu widget yalnızca onları bugüne süzüp gösteriyor. Hiçbir şey yoksa
/// tamamen kayboluyor — boş bir "bugün planın yok" kutusu göstermek
/// ekranı şişirirdi.
class TodayStrip extends ConsumerWidget {
  const TodayStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final items = <_TodayItem>[
      ..._events(ref),
      ..._fees(ref),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              SwanSpace.lg, SwanSpace.sm, SwanSpace.lg, SwanSpace.md),
          child: Text('Bugün', style: SwanType.h3(c.ink)),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: SwanSpace.md),
            itemBuilder: (_, i) => _card(context, c, items[i]),
          ),
        ),
        const SizedBox(height: SwanSpace.xl),
      ],
    );
  }

  /// Bugünün etkinlikleri — antrenman, maç, toplantı.
  List<_TodayItem> _events(WidgetRef ref) {
    final events = ref.watch(eventsProvider).valueOrNull ?? const <EventRow>[];
    final now = DateTime.now();

    return events
        .where((e) =>
            e.startsAt.year == now.year &&
            e.startsAt.month == now.month &&
            e.startsAt.day == now.day &&
            e.startsAt.isAfter(now.subtract(const Duration(hours: 1))))
        .take(4)
        .map((e) => _TodayItem(
              time: _hhmm(e.startsAt),
              title: e.title,
              subtitle: e.place ?? '',
              icon: e.kind == 'match'
                  ? Icons.sports_soccer_rounded
                  : Icons.fitness_center_rounded,
              route: '/calendar',
            ))
        .toList();
  }

  /// Ödenmemiş aidat — tarihi değil, durumu önemli.
  List<_TodayItem> _fees(WidgetRef ref) {
    final fees = ref.watch(myFeesProvider).valueOrNull ?? const <FeeRow>[];
    final open = fees.where((f) => f.status != 'paid').toList();
    if (open.isEmpty) return const [];

    return [
      _TodayItem(
        time: '${open.length}',
        title: 'Ödenmemiş aidat',
        subtitle: 'Aidatlarım',
        icon: Icons.receipt_long_rounded,
        route: '/aidatlarim',
        warn: true,
      ),
    ];
  }

  Widget _card(BuildContext context, SwanPalette c, _TodayItem item) {
    final accent = item.warn ? c.warning : c.accent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          // Zemin farkı yeterli — brief "çok az border" diyor, kenarlık yok.
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Icon(item.icon, size: 16, color: accent),
              const SizedBox(width: SwanSpace.sm),
              Text(item.time,
                  style: SwanType.bodySm(accent, w: FontWeight.w800)),
            ]),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.body(c.ink, w: FontWeight.w700)),
                if (item.subtitle.isNotEmpty)
                  Text(item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

class _TodayItem {
  const _TodayItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.warn = false,
  });

  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  /// Dikkat gerektiren satır (ödenmemiş aidat) — teal yerine amber.
  final bool warn;
}

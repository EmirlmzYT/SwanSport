import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/location/place.dart';
import '../../../app/widgets/premium.dart';
import 'turf_field_detail_screen.dart';

/// Halı saha listesi — courts_screen.dart deseninin aynısı.
///
/// Halı saha kortlardan farklı: sahibi var, ücretli, rezervasyon telefonla
/// yapılıyor. Bu ekran yalnızca doluluk BİLGİSİ gösteriyor, rezervasyon
/// kilidi yok.
class TurfFieldsScreen extends ConsumerStatefulWidget {
  const TurfFieldsScreen({super.key});

  @override
  ConsumerState<TurfFieldsScreen> createState() => _TurfFieldsScreenState();
}

class _TurfFieldsScreenState extends ConsumerState<TurfFieldsScreen> {
  Place? _me;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final place = await currentPlaceOrNull();
      if (mounted && place != null) setState(() => _me = place);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final async = ref.watch(turfFieldsProvider(null));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Halı Sahalar', style: sora(19, FontWeight.w800, ink)),
      ),
      body: async.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (fields) {
          if (fields.isEmpty) {
            return premiumEmpty(
              context,
              icon: Icons.grass_rounded,
              title: 'Henüz halı saha yok',
              subtitle:
                  'Yakında bu şehirdeki halı sahaların doluluğu burada olacak.',
            );
          }

          final sorted = _sortedByDistance(fields);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(turfFieldsProvider(null)),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: sorted.length,
              itemBuilder: (_, i) => _card(isDark, ink, sorted[i]),
            ),
          );
        },
      ),
    );
  }

  List<TurfField> _sortedByDistance(List<TurfField> fields) {
    final me = _me;
    if (me == null) return fields;
    final withDistance = fields
        .map((f) => f.lat == null || f.lng == null
            ? f
            : f.withDistance(metersBetween(me.lat, me.lng, f.lat!, f.lng!)))
        .toList();
    withDistance.sort(
        (a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    return withDistance;
  }

  Widget _card(bool isDark, Color ink, TurfField field) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final subtitle = [
      field.venueName,
      if (field.where.isNotEmpty) field.where,
    ].join(' · ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => TurfFieldDetailScreen(field: field)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3FB950).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.grass_rounded,
                color: Color(0xFF3FB950), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(14, FontWeight.w800, ink)),
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(
                        11.5, FontWeight.w600, SwanColors.textSecondary)),
                const SizedBox(height: 3),
                Text('${field.opensAt} – ${field.closesAt}',
                    style: jakarta(
                        11, FontWeight.w600, SwanColors.textSecondary)),
              ],
            ),
          ),
          if (field.distanceLabel.isNotEmpty)
            PremiumStatusChip(
                label: field.distanceLabel,
                color: const Color(0xFF3FB950),
                icon: Icons.near_me_rounded),
        ]),
      ),
    );
  }
}

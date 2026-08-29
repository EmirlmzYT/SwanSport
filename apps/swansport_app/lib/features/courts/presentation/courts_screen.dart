import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/location/place.dart';
import '../../../app/widgets/premium.dart';
import 'court_detail_screen.dart';
import 'open_slots_screen.dart';

/// Halka açık kortlar.
///
/// Bu ekran kulübü olmayan kullanıcının uygulamada göreceği ilk değerli şey.
/// Rol duvarının arkasına konmaz — konursa tüm amaç boşa çıkar.
///
/// AYRILABİLİRLİK: kort tarafı kulüp kavramlarını bilmez — üyelik, aktif
/// kulüp, lisans ve aidata dokunmaz. Kort dünyası bir gün kendi uygulamasına
/// ayrılacak; bu sınır o gün için. Kontrolü doğrulama adımında yapılıyor.
class CourtsScreen extends ConsumerStatefulWidget {
  const CourtsScreen({super.key});

  @override
  ConsumerState<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends ConsumerState<CourtsScreen> {
  Place? _me;

  @override
  void initState() {
    super.initState();
    // Konum yalnızca listeyi yakınlığa göre sıralamak için; alınamazsa ekran
    // sorunsuz çalışmaya devam eder, sadece mesafe yazmaz.
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

    final async = ref.watch(courtsProvider(null));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Kortlar', style: sora(19, FontWeight.w800, ink)),
        actions: [
          IconButton(
            tooltip: 'Oyuncu aranan oyunlar',
            icon: const Icon(Icons.group_add_rounded, color: kTeal),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const OpenSlotsScreen()),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (courts) {
          if (courts.isEmpty) {
            return premiumEmpty(
              context,
              icon: Icons.sports_tennis_rounded,
              title: 'Henüz kort yok',
              subtitle: 'Yakında bu şehirdeki halka açık kortlar burada olacak.',
            );
          }

          final sorted = _sortedByDistance(courts);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(courtsProvider(null)),
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

  /// Konum biliniyorsa yakından uzağa; bilinmiyorsa gelen sıra korunur.
  List<Court> _sortedByDistance(List<Court> courts) {
    final me = _me;
    if (me == null) return courts;
    final withDistance = courts
        .map((c) =>
            c.withDistance(metersBetween(me.lat, me.lng, c.lat, c.lng)))
        .toList();
    withDistance.sort(
        (a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    return withDistance;
  }

  Widget _card(bool isDark, Color ink, Court court) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final subtitle = [
      if ((court.venue ?? '').isNotEmpty) court.venue!,
      if (court.where.isNotEmpty) court.where,
    ].join(' · ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => CourtDetailScreen(court: court)),
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
              color: kTeal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.sports_tennis_rounded,
                color: kTeal, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(court.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(14, FontWeight.w800, ink)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(
                          11.5, FontWeight.w600, SwanColors.textSecondary)),
                ],
                const SizedBox(height: 3),
                Text('${court.opensAt} – ${court.closesAt}',
                    style: jakarta(
                        11, FontWeight.w600, SwanColors.textSecondary)),
              ],
            ),
          ),
          if (court.distanceLabel.isNotEmpty)
            PremiumStatusChip(
                label: court.distanceLabel,
                color: kTeal,
                icon: Icons.near_me_rounded),
        ]),
      ),
    );
  }
}

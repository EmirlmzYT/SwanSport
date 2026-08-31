import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/location/place.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../turf/presentation/turf_field_detail_screen.dart';
import 'court_detail_screen.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Sahalar — halka açık kortlar ve halı sahalar tek sayfada.
///
/// Önce iki ayrı ekrandı (`courts_screen`, `turf_fields_screen`) ve
/// **neredeyse satır satır aynıydılar**: aynı konum alma, aynı mesafeye göre
/// sıralama, aynı kart iskeleti. İkisini de ben yazmıştım; tekrarı da ben
/// üretmiştim. Kullanıcının bakış açısından da tek soru bunlar: *bugün
/// nerede oynarım?*
///
/// AYRILABİLİRLİK: kort tarafı kulüp kavramlarını bilmez — üyelik, aktif
/// kulüp, lisans ve aidata dokunmaz.
class VenuesScreen extends ConsumerStatefulWidget {
  const VenuesScreen({this.initialTab = 0, super.key});

  /// 0 = Kortlar, 1 = Halı Sahalar.
  ///
  /// Eski `/kortlar` ve `/halisahalar` rotaları korunuyor ve doğru sekmeye
  /// açılıyor — bildirimlerdeki derin bağlantılar kırılmasın diye.
  final int initialTab;

  @override
  ConsumerState<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends ConsumerState<VenuesScreen> {
  late int _tab = widget.initialTab;
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
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Sahalar',
                        style: SwanType.h2(ink)),
                  ),
                  // Kortu gördün ama oynayacak kimsen yok — akış burada
                  // kopuyordu, menüye dönmek gerekiyordu.
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/partner-ara'),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: kTeal.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('Partner bul',
                          style: SwanType.caption(kTeal, w: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SwanSegmentedTabs(
                  labels: const ['Kortlar', 'Halı Sahalar'],
                  selected: _tab,
                  onSelect: (i) => setState(() => _tab = i),
                ),
              ),
              Expanded(
                child: _tab == 0 ? _courtsTab(isDark, ink) : _turfTab(isDark, ink),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // ------------------------------- sekmeler --------------------------------

  Widget _courtsTab(bool isDark, Color ink) {
    final async = ref.watch(courtsProvider(null));
    return async.when(
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
        final sorted = _sorted(courts, (c) => (c.lat, c.lng),
            (c, m) => c.withDistance(m), (c) => c.distanceMeters);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(courtsProvider(null)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
            itemCount: sorted.length,
            itemBuilder: (_, i) => _courtCard(isDark, ink, sorted[i]),
          ),
        );
      },
    );
  }

  Widget _turfTab(bool isDark, Color ink) {
    final async = ref.watch(turfFieldsProvider(null));
    return async.when(
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
        final sorted = _sorted(fields, (f) => (f.lat, f.lng),
            (f, m) => f.withDistance(m), (f) => f.distanceMeters);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(turfFieldsProvider(null)),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
            itemCount: sorted.length,
            itemBuilder: (_, i) => _turfCard(isDark, ink, sorted[i]),
          ),
        );
      },
    );
  }

  /// Konum biliniyorsa yakından uzağa sıralar; bilinmiyorsa gelen sıra kalır.
  ///
  /// İki sekme aynı mantığı paylaşıyor — koordinatı olmayan kayıt (halı
  /// sahada `lat`/`lng` isteğe bağlı) sıralamaya girmez, listede kalır.
  List<T> _sorted<T>(
    List<T> items,
    (double?, double?) Function(T) coords,
    T Function(T, double) withDistance,
    double? Function(T) distanceOf,
  ) {
    final me = _me;
    if (me == null) return items;
    final mapped = items.map((it) {
      final (lat, lng) = coords(it);
      if (lat == null || lng == null) return it;
      return withDistance(it, metersBetween(me.lat, me.lng, lat, lng));
    }).toList();
    mapped.sort((a, b) =>
        (distanceOf(a) ?? double.infinity).compareTo(distanceOf(b) ?? double.infinity));
    return mapped;
  }

  // -------------------------------- kartlar --------------------------------

  Widget _shell(bool isDark, {required Widget child, required VoidCallback onTap}) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: line),
        ),
        child: child,
      ),
    );
  }

  Widget _badge(IconData icon, Color color) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 21),
      );

  Widget _courtCard(bool isDark, Color ink, Court court) {
    final subtitle = [
      if ((court.venue ?? '').isNotEmpty) court.venue!,
      if (court.where.isNotEmpty) court.where,
    ].join(' · ');

    return _shell(
      isDark,
      onTap: () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => CourtDetailScreen(court: court))),
      child: Row(children: [
        _badge(Icons.sports_tennis_rounded, kTeal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(court.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              ],
              const SizedBox(height: 3),
              Text('${court.opensAt} – ${court.closesAt}',
                  style:
                      SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            ],
          ),
        ),
        if (court.distanceLabel.isNotEmpty)
          PremiumStatusChip(
              label: court.distanceLabel,
              color: kTeal,
              icon: Icons.near_me_rounded),
      ]),
    );
  }

  Widget _turfCard(bool isDark, Color ink, TurfField field) {
    const green = Color(0xFF3FB950);
    final subtitle = [
      field.venueName,
      if (field.where.isNotEmpty) field.where,
    ].join(' · ');

    return _shell(
      isDark,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => TurfFieldDetailScreen(field: field))),
      child: Row(children: [
        _badge(Icons.grass_rounded, green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${field.opensAt} – ${field.closesAt}',
                  style:
                      SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            ],
          ),
        ),
        if (field.distanceLabel.isNotEmpty)
          PremiumStatusChip(
              label: field.distanceLabel,
              color: green,
              icon: Icons.near_me_rounded),
      ]),
    );
  }
}

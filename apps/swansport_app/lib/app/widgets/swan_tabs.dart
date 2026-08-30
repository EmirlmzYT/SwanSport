import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import 'premium.dart';

/// Sayfa içi sekme çubukları.
///
/// Bu desen dört ekranda ayrı ayrı kopyalanmıştı (`feed_screen`,
/// `connections_screen`, `finance_screen`, `admin_review_screen`) ve
/// sayfaları birleştirdikçe kopya sayısı artacaktı.
///
/// **İki ayrı stil var ve bilerek birleştirilmedi** — farklı işler yapıyorlar:
///
/// * [SwanSegmentedTabs] — iki-üç kısa etiket, eşit bölünmüş segment.
///   Ekrana sığar, kaydırma yok.
/// * [SwanPillTabs] — çok etiket, yatay kaydırmalı, rozet taşıyabilir.
///
/// İkisini tek stile zorlamak `finance_screen`'in dört sekmesini ve rozetini
/// bozardı.

/// Eşit bölünmüş segment çubuğu — `feed_screen` ve `connections_screen`
/// görünümü.
class SwanSegmentedTabs extends StatelessWidget {
  const SwanSegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final track = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: i == selected ? surf : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  // Seçili segmenti zeminden ayıran ince gölge —
                  // `feed_screen`'den geldi, en olgun kopyası oydu.
                  boxShadow: i == selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(labels[i],
                    style: jakarta(12.5, FontWeight.w800,
                        i == selected ? ink : SwanColors.textSecondary)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Yatay kaydırmalı hap çubuğu — `finance_screen` ve `admin_review_screen`
/// görünümü. Etiket başına isteğe bağlı rozet.
class SwanPillTabs extends StatelessWidget {
  const SwanPillTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.badges = const {},
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// İndeks → rozet sayısı. 0 ya da eksikse rozet çizilmez.
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark ? const Color(0xFF1A2537) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        itemBuilder: (_, i) {
          final active = i == selected;
          final badge = badges[i] ?? 0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? kTeal : idle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? kTeal : line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(labels[i],
                    style: jakarta(12.5, FontWeight.w800,
                        active ? Colors.white : SwanColors.textSecondary)),
                if (badge > 0) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: .25)
                          : const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(badge > 9 ? '9+' : '$badge',
                        style:
                            jakarta(9.5, FontWeight.w800, Colors.white)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

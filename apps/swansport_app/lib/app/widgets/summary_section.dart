import 'package:flutter/material.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Başlık + kısa özet + "Tümünü gör".
///
/// Brief §10: *"Bunların tamamını ana ekranda göstermeye çalışma. Her bölüm
/// için kısa özet + 'Tümünü gör' kullan."*
///
/// Eskisi bunun tersiydi: sporcu ana ekranında dört düğmelik bir kısayol
/// ızgarası vardı ve düğmeler **hiçbir şey söylemiyordu** — "Belgelerim"
/// yazıyordu ama belgen eksik mi tam mı, girmeden anlaşılmıyordu. Ana ekranın
/// işi yönlendirmek değil, **bakınca durumu anlatmak**; girmeye değip
/// değmediğine buradan karar verilebilmeli.
///
/// Bu yüzden [child] bir düğme değil bir **cevap** olmalı: "2 ödenmemiş,
/// 1.500 ₺", "Sağlam", "3 belge eksik". Sayı yoksa bölümü boş bırakma —
/// [SummaryLine.empty] ile "kayıt yok" de; sessiz boşluk hata gibi görünüyor.
class SummarySection extends StatelessWidget {
  const SummarySection({
    required this.title,
    required this.child,
    this.onSeeAll,
    this.seeAllLabel = 'Tümünü gör',
    super.key,
  });

  final String title;
  final Widget child;

  /// Null ise "Tümünü gör" çizilmez — gidilecek bir ekran olmadığında
  /// tıklanmayan bir bağlantı göstermek yalan olur.
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Padding(
      padding: const EdgeInsets.only(top: SwanSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: SwanType.h3(c.ink))),
              if (onSeeAll != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSeeAll,
                  child: Padding(
                    // Dokunma alanı metinden büyük olsun; 12px'lik bir yazıya
                    // tam oturan hedef parmakla ıskalanıyor.
                    padding: const EdgeInsets.symmetric(
                        horizontal: SwanSpace.xs, vertical: SwanSpace.sm),
                    child: Row(children: [
                      Text(seeAllLabel,
                          style: SwanType.caption(c.accent,
                              w: FontWeight.w700)),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: c.accent),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          child,
        ],
      ),
    );
  }
}

/// Bir özet satırı — ikon + durum + isteğe bağlı alt satır.
///
/// Renk **duruma** göre veriliyor ama renk tek başına anlam taşımıyor:
/// yanında her zaman metin var. Bu bilinçli — kırmızı/yeşil ayrımı renk körü
/// kullanıcıda kayboluyor, metin kaybolmuyor.
class SummaryLine extends StatelessWidget {
  const SummaryLine({
    required this.icon,
    required this.text,
    this.sub,
    this.tone,
    super.key,
  });

  /// İçerik yokken kullanılacak sessiz hâl.
  factory SummaryLine.empty(String text) =>
      SummaryLine(icon: Icons.remove_rounded, text: text);

  final IconData icon;
  final String text;
  final String? sub;

  /// Null ise nötr (ink). Doluysa durum rengi — `success`, `warning`, `danger`.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final accent = tone ?? c.inkMuted;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SwanSpace.lg, vertical: SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(c.inkMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

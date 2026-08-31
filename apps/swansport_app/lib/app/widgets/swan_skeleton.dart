import 'package:flutter/material.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';

/// Yükleniyor iskeleti — yumuşak parıltıyla.
///
/// Brief §21: *"skeleton loading → soft shimmer"* ve *"uygulama hızlı
/// hissettirmeli"*. Dönen çember bekleme hissini uzatıyor: ekran boş kalıyor,
/// ne geleceği belli olmuyor. İskelet gelecek içeriğin biçimini önceden
/// gösteriyor — aynı süre, daha kısa hissettiren bir bekleme.
///
/// `premiumLoading()` bunu 39 ekranda birden kullanıyor; şekli buradan
/// değiştirmek hepsini değiştiriyor.

/// Parıldayan tek bir blok.
class SwanShimmer extends StatefulWidget {
  const SwanShimmer({
    required this.width,
    required this.height,
    this.radius = SwanRadius.sm,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<SwanShimmer> createState() => _SwanShimmerState();
}

class _SwanShimmerState extends State<SwanShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // Soldan sağa geçen yumuşak bir vurgu. Brief "abartılı animasyon
        // kullanma" diyor: tek geçiş, düşük kontrast.
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t), 0),
              colors: [
                c.surfaceAlt,
                c.isDark
                    ? c.line.withValues(alpha: .55)
                    : c.line.withValues(alpha: .85),
                c.surfaceAlt,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Liste iskeleti — avatar + iki satır, birkaç kez tekrar.
///
/// Uygulamadaki ekranların çoğu liste; tek bir genel şekil ekranların
/// büyük kısmına oturuyor. Ekrana özel iskelet gerekirse [SwanShimmer]
/// ile kendi düzenini kur.
class SwanListSkeleton extends StatelessWidget {
  const SwanListSkeleton({this.rows = 5, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: SwanSpace.lg, vertical: SwanSpace.md),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: SwanSpace.lg),
              child: Row(children: [
                const SwanShimmer(
                    width: 48, height: 48, radius: SwanRadius.md),
                const SizedBox(width: SwanSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Satır genişlikleri hafif değişiyor: eşit uzunlukta
                      // bloklar gerçek içerikten çok tabloya benziyor.
                      SwanShimmer(width: i.isEven ? 160 : 130, height: 13),
                      const SizedBox(height: SwanSpace.sm),
                      SwanShimmer(width: i.isEven ? 220 : 190, height: 11),
                    ],
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

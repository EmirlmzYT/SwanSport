import 'package:flutter/material.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Seçilebilir filtre etiketi.
///
/// **Neden paylaşılan:** aynı `_chip(...)` yardımcısı dört ekranda birbirinden
/// bağımsız kopyalanmış (`find_partner_screen`, `search_screen`,
/// `athlete_workspace_screen`, `athlete_profile_section`) ve kopyalar sabit
/// renk kullanıyor — biri `0xFFF4F7FA` yazıyor, jetonu değiştirince o ekran
/// yerinde kalıyor. Beşinci kopyayı yazmamak için burada duruyor.
///
/// Seçili zemin `accent` değil **`accentFill`**: üstünde beyaz metin var ve
/// parlak teal ile beyaz kontrastı 3:1 eşiğinin altına düşüyor.
/// `test/swan_contrast_test.dart` bunu sabitliyor.
class SwanChip extends StatelessWidget {
  const SwanChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final fg = selected ? Colors.white : c.ink;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SwanSpace.md, vertical: SwanSpace.sm),
        decoration: BoxDecoration(
          color: selected ? c.accentFill : c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: SwanType.caption(fg, w: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Yatay kaydırılan filtre şeridi.
///
/// Filtreler tek satırda durur ve taşarsa kaydırılır — sarmalayıp iki satıra
/// yaymak listeyi aşağı itiyor, asıl içerik ekranın dışında kalıyordu.
class SwanChipBar extends StatelessWidget {
  const SwanChipBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: SwanSpace.sm),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}

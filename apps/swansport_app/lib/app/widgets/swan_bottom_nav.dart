import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import 'create_sheet.dart';

/// Sabit beş öğeli alt gezinme.
///
/// **Eskisinden iki farkı var.**
///
/// 1. **Yuvalar artık role göre değişmiyor.** `PremiumBottomNav` ikinci ve
///    dördüncü sekmeyi rolün erişebildiği ilk hedefe göre seçiyordu —
///    aynı konum kişiden kişiye farklı şey açıyordu, kas hafızası kurulamıyordu.
///    Rol farkı artık sekmede değil **içerikte**: antrenörün yoklaması Ana
///    Sayfa'daki "Bugün" bloğunda ve Profil > Yönetim'de.
///
/// 2. **Parametre almıyor.** Eskisi `selectedIndex`/`onSelect`/`onAction`
///    istiyordu ve 31 ekranın 25'i bunları boş geçiyordu
///    (`selectedIndex: -1, onSelect: (_) {}, onAction: () {}`). Aktif sekme
///    zaten açık rotadan anlaşılıyor; o gürültü kalktı.
class SwanBottomNav extends ConsumerWidget {
  const SwanBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final current = ModalRoute.of(context)?.settings.name;
    // Açılış kapısı akışı gösteriyor.
    final route = current == '/' ? '/akis' : current;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.md),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            // Brief "çok az shadow" diyor: tek yumuşak gölge, border yok.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.isDark ? .45 : .10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Tab(
                icon: Icons.home_rounded,
                label: 'Ana Sayfa',
                active: route == '/akis',
                onTap: () => _go(context, '/akis'),
              ),
              _Tab(
                icon: Icons.explore_rounded,
                label: 'Keşfet',
                active: route == '/kesfet',
                onTap: () => _go(context, '/kesfet'),
              ),
              const _CreateButton(),
              _Tab(
                icon: Icons.chat_bubble_rounded,
                label: 'Mesajlar',
                active: route == '/mesajlar',
                onTap: () => _go(context, '/mesajlar'),
              ),
              _Tab(
                icon: Icons.person_rounded,
                label: 'Profil',
                active: route == '/profil',
                onTap: () => myId == null
                    ? null
                    : Navigator.pushNamed(context, '/profil',
                        arguments: myId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamed(context, route);
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    // Aktif durum teal — brief'in kuralı: teal yalnızca önemli aksiyon ve
    // aktif durum için.
    final color = active ? c.accent : c.inkMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.caption(color,
                    w: active ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Ortadaki "+" — bağlama göre oluşturma eylemleri.
class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showCreateSheet(context),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

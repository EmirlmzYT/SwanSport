import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'action_gate.dart';

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
/// **Kaydırarak seçim.** Çubuğa basılı tutup parmağını yana kaydırınca seçim
/// parmağı takip ediyor, bırakınca o sekme açılıyor. Normal dokunuş eskisi
/// gibi doğrudan gidiyor — iki jest çakışmıyor çünkü kaydırma yalnızca uzun
/// basıştan sonra başlıyor.
///
/// Hangi sekmenin üstünde olduğun `GlobalKey` ile gerçek yerleşimden
/// ölçülüyor, sabit genişlik hesabıyla değil: satır `spaceBetween` ve ekran
/// genişliğine göre değişiyor, elle hesaplasak dar telefonda kayardı.
///
/// Ortadaki "+" kaydırmada atlanıyor. O bir hedef değil bir eylem; parmak
/// üstünden geçerken sayfa açmak ya da bırakınca yanlışlıkla paylaşım
/// sayfası çıkarmak sürpriz olurdu.
class SwanBottomNav extends ConsumerStatefulWidget {
  const SwanBottomNav({super.key});

  @override
  ConsumerState<SwanBottomNav> createState() => _SwanBottomNavState();
}

class _SwanBottomNavState extends ConsumerState<SwanBottomNav> {
  /// Dört gezinme sekmesinin yerleşimdeki karşılığı.
  final _keys = List.generate(4, (_) => GlobalKey());

  /// Kaydırma sırasında parmağın üstünde olduğu sekme. `null` = kaydırma yok.
  int? _scrub;

  /// Parmağın yatayda hangi sekmenin üstünde olduğu.
  ///
  /// Yalnızca `dx` bakılıyor: parmak kaydırırken dikeyde çubuğun dışına
  /// çıkıyor ve dikey kontrol koysaydık seçim ortada kaybolurdu.
  int? _indexAt(Offset globalPos) {
    for (var i = 0; i < _keys.length; i++) {
      final box = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final left = box.localToGlobal(Offset.zero).dx;
      if (globalPos.dx >= left && globalPos.dx <= left + box.size.width) {
        return i;
      }
    }
    return null;
  }

  void _preview(Offset pos) {
    final i = _indexAt(pos);
    // "+" üstündeyken (i == null) önceki seçim korunuyor; boşa düşürmek
    // parmak ortadan geçerken seçimin yanıp sönmesi demekti.
    if (i == null || i == _scrub) return;
    HapticFeedback.selectionClick();
    setState(() => _scrub = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final current = ModalRoute.of(context)?.settings.name;
    // Açılış kapısı akışı gösteriyor.
    final route = current == '/' ? '/akis' : current;
    final myId = ref.watch(currentProfileProvider).valueOrNull?.id;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;

    // Hedefler tek yerde: hem çizim hem kaydırma bunu okuyor, ikisi ayrışamaz.
    final targets = <_NavTarget>[
      const _NavTarget(
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
        label: 'Ana Sayfa',
        route: '/akis',
      ),
      const _NavTarget(
        activeIcon: Icons.explore_rounded,
        inactiveIcon: Icons.explore_outlined,
        label: 'Keşfet',
        route: '/kesfet',
      ),
      const _NavTarget(
        activeIcon: Icons.chat_bubble_rounded,
        inactiveIcon: Icons.chat_bubble_outline_rounded,
        label: 'Mesajlar',
        route: '/mesajlar',
      ),
      const _NavTarget(
        activeIcon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline_rounded,
        label: 'Profil',
        route: '/profil',
      ),
    ];

    return SafeArea(
      top: false,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPressStart: (d) {
          HapticFeedback.selectionClick();
          setState(() => _scrub = _indexAt(d.globalPosition));
        },
        onLongPressMoveUpdate: (d) => _preview(d.globalPosition),
        onLongPressEnd: (d) {
          final i = _scrub;
          setState(() => _scrub = null);
          if (i == null) return;
          final t = targets[i];
          _go(context, t.route, profileId: myId);
        },
        onLongPressCancel: () => setState(() => _scrub = null),
        onHorizontalDragStart: isIos
            ? (d) {
                HapticFeedback.selectionClick();
                setState(() => _scrub = _indexAt(d.globalPosition));
              }
            : null,
        onHorizontalDragUpdate:
            isIos ? (d) => _preview(d.globalPosition) : null,
        onHorizontalDragEnd: isIos
            ? (_) {
                final i = _scrub;
                setState(() => _scrub = null);
                if (i == null) return;
                final target = targets[i];
                _go(context, target.route, profileId: myId);
              }
            : null,
        onHorizontalDragCancel:
            isIos ? () => setState(() => _scrub = null) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 0, SwanSpace.lg, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: isIos ? 18 : 0,
                sigmaY: isIos ? 18 : 0,
              ),
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: isIos
                      ? c.surface.withValues(alpha: c.isDark ? .76 : .68)
                      : c.surface,
                  borderRadius: BorderRadius.circular(SwanRadius.lg),
                  border: isIos
                      ? Border.all(color: Colors.white.withValues(alpha: .22))
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: c.isDark ? .45 : .10),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < targets.length; i++) ...[
                      if (i == 2) const _CreateButton(),
                      Expanded(
                          child: _Tab(
                        key: _keys[i],
                        icon: (_scrub == null
                                ? route == targets[i].route
                                : _scrub == i)
                            ? targets[i].activeIcon
                            : targets[i].inactiveIcon,
                        label: targets[i].label,
                        active: _scrub == null
                            ? route == targets[i].route
                            : _scrub == i,
                        scrubbing: _scrub == i,
                        onTap: () {
                          _go(context, targets[i].route, profileId: myId);
                        },
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _go(BuildContext context, String route,
      {String? profileId}) async {
    if (!SwanAccess.isGuestRoute(route) &&
        !await requireSwanAction(context, ref, SwanAction.message)) return;
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushReplacementNamed(context, route,
        arguments: route == '/profil' ? profileId : null);
  }
}

/// Alt çubuktaki bir gezinme hedefi.
class _NavTarget {
  const _NavTarget({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.route,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final String route;
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.scrubbing = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// Parmak şu an bu sekmenin üstünde. Görsel olarak öne çıkıyor ki
  /// kullanıcı bırakmadan önce nereye gideceğini görsün.
  final bool scrubbing;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    // Aktif durum teal — brief'in kuralı: teal yalnızca önemli aksiyon ve
    // aktif durum için.
    final color = active ? c.accent : c.inkMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedScale(
        // Kısa ve az: 1.08 fark edilir ama zıplamıyor.
        scale: scrubbing ? 1.08 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 60,
          decoration: BoxDecoration(
            // Yalnızca kaydırma sırasında zemin: parmağın altındaki sekme
            // bırakmadan önce belli olsun. Normal durumda çubuk sade kalıyor.
            color: active ? c.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}

/// Ortadaki "+" — bağlama göre oluşturma eylemleri.
class _CreateButton extends ConsumerWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (await requireSwanAction(context, ref, SwanAction.publish) &&
            context.mounted) {
          await showCreateSheet(context);
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          // `accent` değil `accentFill`: üstünde beyaz ikon var. Koyu temada
          // parlak teal + beyaz 2.27:1 veriyordu, eşik 3:1.
          color: c.accentFill,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

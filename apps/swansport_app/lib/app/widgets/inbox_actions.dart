import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_type.dart';

/// Üst barın sağındaki "gelen kutusu" ikonları: bildirimler (hareketler) + mesajlar.
///
/// **Kural:** üst sağ = okunmamışı olan şeyler, alt bar = bölümler arası
/// gezinme, header'daki avatar = yalnızca kimlik göstergesi (Profil zaten
/// alt barda, iki yerde olmasın).
///
/// Minimalist Instagram tarzı: çerçevesiz 44x44 dokunma alanı, kalp ve gönder ikonları.
class InboxActions extends ConsumerWidget {
  const InboxActions({super.key, this.spacing = 4});

  /// İki ikon arasındaki boşluk.
  final double spacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadNotifications =
        ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final unreadMessages = ref.watch(unreadMessagesProvider).valueOrNull ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InboxIconButton(
          icon: Icons.favorite_border_rounded,
          badge: unreadNotifications,
          tooltip: 'Hareketler',
          onTap: () => Navigator.pushNamed(context, '/bildirimler'),
        ),
        SizedBox(width: spacing),
        InboxIconButton(
          icon: Icons.send_outlined,
          badge: unreadMessages,
          tooltip: 'Mesajlar',
          onTap: () => Navigator.pushNamed(context, '/mesajlar'),
        ),
      ],
    );
  }
}

/// Rozetli, tıklanabilir üst bar ikonu.
///
/// Minimalist ve çerçevesiz: 44x44 dokunma alanı, ortalanmış 24px ikon,
/// yalnızca okunmamış > 0 olduğunda sağ üstte minik kırmızı rozet.
class InboxIconButton extends StatelessWidget {
  const InboxIconButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// 0 ise rozet hiç çizilmez — "0" yazan bir rozet gürültüdür.
  final int badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.center,
              child: Icon(icon, size: 24, color: c.ink),
            ),
            if (badge > 0)
              Positioned(
                top: 4,
                right: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: c.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                  child: Text(
                    badgeLabel(badge),
                    textAlign: TextAlign.center,
                    style: SwanType.caption(Colors.white, w: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Rozet metni: 9'dan sonrası `9+`.
///
/// İki haneli sayı 17px'lik rozete sığmıyor ve tam sayı zaten bilgi
/// taşımıyor — "çok var" demek yeterli.
String badgeLabel(int count) => count > 9 ? '9+' : '$count';

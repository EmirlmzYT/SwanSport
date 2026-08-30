import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import 'premium.dart';

/// Üst barın sağındaki "gelen kutusu" ikonları: bildirimler + mesajlar.
///
/// **Kural:** üst sağ = okunmamışı olan şeyler, alt bar = bölümler arası
/// gezinme, header'daki avatar = yalnızca kimlik göstergesi (Profil zaten
/// alt barda, iki yerde olmasın).
///
/// Neden tek bileşen: aynı zil beş ana ekranda ayrı ayrı kopyalanmıştı ve
/// **beşi de ölüydü** — düz `Container`, `onTap` yok, kullanıcı basıyor
/// hiçbir şey olmuyordu. Rozet de yalnızca akış ekranında vardı. Tek yerde
/// durunca bu tür sessiz kopmalar olmuyor.
class InboxActions extends ConsumerWidget {
  const InboxActions({super.key, this.spacing = 8});

  /// İki ikon arasındaki boşluk.
  final double spacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadNotifications =
        ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final unreadMessages = ref.watch(unreadMessagesProvider).valueOrNull ?? 0;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      InboxIconButton(
        icon: Icons.notifications_none_rounded,
        badge: unreadNotifications,
        tooltip: 'Bildirimler',
        onTap: () => Navigator.pushNamed(context, '/bildirimler'),
      ),
      SizedBox(width: spacing),
      InboxIconButton(
        icon: Icons.chat_bubble_outline_rounded,
        badge: unreadMessages,
        tooltip: 'Mesajlar',
        onTap: () => Navigator.pushNamed(context, '/mesajlar'),
      ),
    ]);
  }
}

/// Rozetli, tıklanabilir üst bar ikonu.
///
/// Görsel dil `feed_screen`'deki çalışan zilden alındı: 40x40 yuvarlak
/// köşeli kutu, sağ üstte kırmızı rozet.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);

    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: line),
          ),
          child: Icon(icon, size: 21, color: SwanColors.textSecondary),
        ),
        if (badge > 0)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E),
                borderRadius: BorderRadius.circular(999),
                // Rozetin çevresindeki ince halka onu zeminden ayırıyor;
                // ekranın zemin rengiyle aynı olmalı, kutunun değil.
                border: Border.all(color: bg, width: 1.5),
              ),
              child: Text(badgeLabel(badge),
                  textAlign: TextAlign.center,
                  style: jakarta(9.5, FontWeight.w800, Colors.white)),
            ),
          ),
      ]),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Rozet metni: 9'dan sonrası `9+`.
///
/// İki haneli sayı 17px'lik rozete sığmıyor ve tam sayı zaten bilgi
/// taşımıyor — "çok var" demek yeterli.
String badgeLabel(int count) => count > 9 ? '9+' : '$count';

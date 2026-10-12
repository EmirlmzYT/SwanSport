import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart' show SwanNetworkLogo;
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/inbox_actions.dart';

/// Atletik marka ve gerçek okunmamış sayaçları; hikaye sistemi değildir.
class StitchFeedTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const StitchFeedTopBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final config = ref.watch(platformConfigProvider).valueOrNull;
    final name = config?.appName?.trim();
    final appName = name == null || name.isEmpty ? 'SwanSport' : name;
    final logoUrl = config?.logoUrl?.trim();
    final hasAccount = ref.watch(swanAccessProvider).hasAccount;
    final notifications = hasAccount ? ref.watch(unreadNotificationsProvider).valueOrNull ?? 0 : 0;
    final messages = hasAccount ? ref.watch(unreadMessagesProvider).valueOrNull ?? 0 : 0;
    return Material(
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
        child: Row(children: [
          Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (logoUrl != null && logoUrl.isNotEmpty)
              Padding(padding: const EdgeInsets.only(right: SwanSpace.sm),
                child: ClipRRect(borderRadius: BorderRadius.circular(SwanRadius.sm),
                  child: SwanNetworkLogo(url: logoUrl, size: SwanSpace.xl,
                    semanticLabel: appName, fallback: const SizedBox.shrink()))),
            Flexible(child: Text(appName, maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.wordmark(c.ink))),
            const SizedBox(width: SwanSpace.xs),
            ExcludeSemantics(child: Icon(Icons.circle, size: SwanSpace.sm, color: c.accent)),
          ])),
          InboxIconButton(icon: Icons.notifications_none_rounded, color: c.inkMuted, badge: notifications, tooltip: 'Bildirimler', onTap: () => Navigator.pushNamed(context, '/bildirimler')),
          InboxIconButton(icon: Icons.send_outlined, color: c.inkMuted, badge: messages, tooltip: 'Mesajlar', onTap: () => Navigator.pushNamed(context, '/mesajlar')),
          if (!hasAccount) TextButton(onPressed: () => Navigator.pushNamed(context, '/auth'), child: Text('Giriş Yap', style: SwanType.caption(c.accent, w: FontWeight.w700))),
        ]),
      ),
    );
  }
}

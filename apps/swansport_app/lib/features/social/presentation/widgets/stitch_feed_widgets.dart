import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart'
    show SwanNetworkLogo;
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_chrome.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/swan_floating_header.dart';

/// Akış seçimi ve bildirimler; oluşturma ile mesajlar alt çubukta.
class StitchFeedTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const StitchFeedTopBar(
      {super.key,
      this.followingOnly = false,
      this.onFeedChanged,
      this.allLabel = 'Tümü (Keşfet)',
      this.followingLabel = 'Takip Ettiklerim'});
  final bool followingOnly;
  final ValueChanged<bool>? onFeedChanged;
  final String allLabel, followingLabel;
  @override
  Size get preferredSize => const Size.fromHeight(SwanChrome.headerHeight);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final config = ref.watch(platformConfigProvider).valueOrNull;
    final name = config?.appName?.trim();
    final appName = name == null || name.isEmpty ? 'SwanSport' : name;
    final logoUrl = config?.logoUrl?.trim();
    final hasAccount = ref.watch(swanAccessProvider).hasAccount;
    final notifications = hasAccount
        ? ref.watch(unreadNotificationsProvider).valueOrNull ?? 0
        : 0;
    final brand = Padding(
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.xs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (logoUrl != null && logoUrl.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(right: SwanSpace.xs),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    child: SwanNetworkLogo(
                        url: logoUrl,
                        size: SwanSpace.lg,
                        semanticLabel: appName,
                        fallback: const SizedBox.shrink()))),
          Flexible(
              child: Text(appName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.navigationWordmark(c.ink))),
          if (onFeedChanged != null) ...[
            const SizedBox(width: SwanSpace.xs),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: SwanSpace.lg, color: c.ink),
          ],
        ]));
    return SwanFloatingHeader(
      title: onFeedChanged == null
          ? brand
          : PopupMenuButton<bool>(
              tooltip: 'Akış seçimi',
              initialValue: followingOnly,
              onSelected: onFeedChanged,
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                    value: false,
                    checked: !followingOnly,
                    child: Text(allLabel)),
                CheckedPopupMenuItem(
                    value: true,
                    checked: followingOnly,
                    child: Text(followingLabel)),
              ],
              child: SizedBox(
                  height: SwanChrome.touchTarget, child: Center(child: brand)),
            ),
      actions: [
        InboxIconButton(
            icon: Icons.notifications_none_rounded,
            badge: notifications,
            tooltip: 'Bildirimler',
            onTap: () => Navigator.pushNamed(context, '/bildirimler')),
      ],
    );
  }
}

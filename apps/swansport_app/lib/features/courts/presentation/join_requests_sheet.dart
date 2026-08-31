import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Oyununa katılmak isteyenler.
///
/// Katılım sahibin onayıyla: kortta kiminle karşılaşacağını seçebilmek,
/// özellikle yeni başlayanlar için sistemin kullanılabilirlik şartı.
class JoinRequestsSheet extends ConsumerWidget {
  const JoinRequestsSheet({required this.slotId, super.key});

  final String slotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final async = ref.watch(joinRequestsProvider(slotId));

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 18, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 4,
          decoration:
              BoxDecoration(color: line, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),
        Text('Katılmak isteyenler', style: SwanType.h3(ink)),
        const SizedBox(height: 12),
        async.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (requests) {
            final pending = requests.where((r) => r.isPending).toList();
            if (pending.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 26),
                child: Text('Henüz isteyen yok.',
                    style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              );
            }
            return Column(
              children: [
                for (final r in pending) _row(context, ref, isDark, ink, r),
              ],
            );
          },
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, bool isDark, Color ink,
      JoinRequest r) {
    Widget action(String label, Color color, bool accept) => GestureDetector(
          onTap: () async {
            try {
              await ref.read(courtServiceProvider).reviewJoin(
                    slotId: slotId,
                    profileId: r.profileId,
                    accept: accept,
                  );
              ref.invalidate(joinRequestsProvider(slotId));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          },
          child: Container(
            height: 33,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: accept ? 1 : .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: SwanType.caption(accept ? Colors.white : color, w: FontWeight.w800)),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SocialAvatar(
          initials: r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
          imageUrl: r.avatarUrl,
          size: 36,
          radius: 12,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(r.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SwanType.bodySm(ink, w: FontWeight.w700)),
        ),
        action('Kabul', kTeal, true),
        const SizedBox(width: 7),
        action('Ret', const Color(0xFFD64545), false),
      ]),
    );
  }
}

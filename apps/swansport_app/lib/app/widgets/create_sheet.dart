import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../features/social/presentation/post_composer_sheet.dart';
import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Alt gezinmedeki "+" — oluşturma eylemleri.
///
/// Brief §20: *"Birçok işlemi yeni sayfa açmak yerine bottom sheet ile çöz."*
/// Eskiden buradaki düğme 34 girişlik modül kataloğunu açıyordu; artık
/// yalnızca **oluşturulabilecek şeyleri** gösteriyor.
///
/// Liste role göre kısalıyor: kulüpte görevi olmayan biri duyuru
/// oluşturamaz, o satır hiç görünmüyor — kapalı bir düğme göstermek yerine.
Future<void> showCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CreateSheet(),
  );
}

class _CreateSheet extends ConsumerWidget {
  const _CreateSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);

    final items = <_CreateItem>[
      const _CreateItem(
        icon: Icons.edit_rounded,
        title: 'Gönderi',
        subtitle: 'Akışta paylaş',
        kind: _CreateKind.post,
      ),
      if (access.hasVerificationTier('location'))
        const _CreateItem(
          icon: Icons.handshake_rounded,
          title: 'Partner ilanı',
          subtitle: 'Birlikte oynayacak birini bul',
          route: '/partner-ara',
        ),
      const _CreateItem(
        icon: Icons.campaign_rounded,
        title: 'İlan',
        subtitle: 'Malzeme sat ya da ara',
        route: '/ilanlar',
      ),
      if (access.isClubStaff)
        const _CreateItem(
          icon: Icons.event_rounded,
          title: 'Etkinlik',
          subtitle: 'Antrenman, maç ya da toplantı',
          route: '/calendar',
        ),
      if (access.isClubStaff)
        const _CreateItem(
          icon: Icons.notifications_active_rounded,
          title: 'Duyuru',
          subtitle: 'Kulübe haber ver',
          route: '/announcements',
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
      ),
      padding: EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md, SwanSpace.lg,
          SwanSpace.lg + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: c.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: SwanSpace.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Oluştur', style: SwanType.h2(c.ink)),
        ),
        const SizedBox(height: SwanSpace.md),
        for (final item in items) _row(context, c, item),
      ]),
    );
  }

  Widget _row(BuildContext context, SwanPalette c, _CreateItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        Navigator.pop(context);
        if (item.kind == _CreateKind.post) {
          await showPostComposer(context);
        } else if (item.route != null) {
          if (context.mounted) Navigator.pushNamed(context, item.route!);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Icon(item.icon, color: c.accent, size: 21),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: SwanType.body(c.ink, w: FontWeight.w700)),
                Text(item.subtitle, style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.inkMuted),
        ]),
      ),
    );
  }
}

enum _CreateKind { post, route }

class _CreateItem {
  const _CreateItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    this.kind = _CreateKind.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final _CreateKind kind;
}

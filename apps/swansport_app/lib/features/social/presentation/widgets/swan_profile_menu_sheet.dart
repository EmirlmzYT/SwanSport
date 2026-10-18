import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../network/presentation/swan_card_sheet.dart';
import 'management_section.dart';

Future<void> showSwanProfileMenu(
  BuildContext context,
  SocialProfile profile,
) async {
  final route = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.swan.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
    ),
    builder: (context) => _ProfileMenu(profile: profile),
  );
  if (!context.mounted || route == null) return;
  if (route == 'swan-card') {
    await showSwanCard(
      context,
      id: profile.id,
      name: profile.name,
      isClub: profile.isClub,
      subtitle: profile.roleLabel,
      avatarUrl: profile.avatarUrl,
    );
  } else {
    await Navigator.pushNamed(context, route);
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    void open(String route) => Navigator.pop(context, route);

    Widget entry(IconData icon, String label, String route) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: c.inkMuted),
          title: Text(label, style: SwanType.body(c.ink)),
          trailing: Icon(Icons.chevron_right_rounded, color: c.inkMuted),
          onTap: () => open(route),
        );

    return FractionallySizedBox(
      heightFactor: .85,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg,
          0,
          SwanSpace.lg,
          SwanSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Profil menüsü', style: SwanType.h2(c.ink)),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(profile.name, style: SwanType.bodySm(c.inkMuted)),
            const SizedBox(height: SwanSpace.md),
            entry(Icons.settings_outlined, 'Ayarlar', '/settings'),
            entry(Icons.qr_code_2_rounded, 'Sporcu Kartı', 'swan-card'),
            Divider(color: c.line),
            Text('Kişisel', style: SwanType.h3(c.ink)),
            entry(
              Icons.bookmark_border_rounded,
              'Kaydedilenler',
              '/kaydedilenler',
            ),
            if (ref.watch(
              featureEnabledProvider(FeatureFlags.sportTrainingSessions),
            ))
              entry(Icons.sports_rounded, 'Antrenmanlarım', '/antrenmanlarim'),
            entry(Icons.receipt_long_outlined, 'Aidatlarım', '/aidatlarim'),
            entry(Icons.folder_outlined, 'Belgelerim', '/documents'),
            entry(Icons.verified_user_outlined, 'Doğrulama', '/dogrulama'),
            if (!profile.isClub &&
                ref.watch(swanAccessProvider).isReferee &&
                ref.watch(featureEnabledProvider(FeatureFlags.refereeCockpit)))
              entry(
                Icons.sports_outlined,
                'Hakem Görevlerim',
                '/hakem/gorevler',
              ),
            ManagementSection(compact: true, onNavigate: open),
          ],
        ),
      ),
    );
  }
}

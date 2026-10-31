import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../network/presentation/swan_card_sheet.dart';

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
    final access = ref.watch(swanAccessProvider);
    void open(String route) => Navigator.pop(context, route);

    Widget entry(
      IconData icon,
      String label,
      String route, {
      String? subtitle,
      Color? iconColor,
    }) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icon, color: iconColor ?? c.inkMuted, size: 22),
          title: Text(label, style: SwanType.body(c.ink)),
          subtitle: subtitle != null
              ? Text(subtitle, style: SwanType.caption(c.inkMuted))
              : null,
          trailing:
              Icon(Icons.chevron_right_rounded, color: c.inkMuted, size: 20),
          onTap: () => open(route),
        );

    Widget sectionHeader(String title) => Padding(
          padding:
              const EdgeInsets.only(top: SwanSpace.md, bottom: SwanSpace.xs),
          child: Text(
            title,
            style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
          ),
        );

    final hasDevReport =
        ref.watch(featureEnabledProvider(FeatureFlags.developmentReport));

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
            // Başlık ve kullanıcı kimliği
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Menü', style: SwanType.h2(c.ink)),
                      const SizedBox(height: SwanSpace.xs),
                      Text(
                        profile.roleLabel != null
                            ? '${profile.name} • ${profile.roleLabel}'
                            : profile.name,
                        style: SwanType.bodySm(c.inkMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: SwanSpace.md),

            // Sosyal uygulamada kişisel alanlar kalır; yönetim operasyonları
            // SwanSport Pro'dan yürütülür.
            sectionHeader('KİŞİSEL'),
            entry(
              Icons.qr_code_2_rounded,
              'Sporcu Kartı (QR)',
              'swan-card',
              subtitle: 'Dijital sporcu kimliğini göster veya paylaş',
            ),
            entry(
              Icons.bookmark_border_rounded,
              'Kaydedilenler',
              '/kaydedilenler',
            ),
            entry(Icons.receipt_long_outlined, 'Aidatlarım', '/aidatlarim'),
            entry(Icons.folder_outlined, 'Belgelerim', '/documents'),
            entry(Icons.verified_user_outlined, 'Doğrulama', '/dogrulama'),
            if (hasDevReport)
              entry(
                Icons.insights_rounded,
                'Gelişim Raporu',
                '/gelisim-raporu',
              ),
            Divider(color: c.line, height: SwanSpace.xl),

            // 3. HESAP VE DESTEK
            sectionHeader('HESAP VE DESTEK'),
            entry(Icons.settings_outlined, 'Ayarlar', '/settings'),
            entry(Icons.auto_stories_rounded, 'Kurulum Rehberi', '/rehber'),
            entry(Icons.volunteer_activism_rounded, 'Bağış & Destek', '/bagis'),
            entry(Icons.group_add_rounded, 'Başvurularım', '/basvurular'),
            entry(Icons.vpn_key_rounded, 'Davet Kodu Ekle', '/veli-bagla'),

            // 4. PLATFORM (Yalnızca platform admin)
            if (access.isPlatformAdmin) ...[
              Divider(color: c.line, height: SwanSpace.xl),
              sectionHeader('PLATFORM'),
              entry(
                Icons.admin_panel_settings_rounded,
                'Onay Paneli',
                '/onay-paneli',
              ),
              entry(
                Icons.rss_feed_rounded,
                'Haber Kaynakları',
                '/haber-kaynaklari',
              ),
              entry(
                Icons.verified_rounded,
                'Federasyon Yetkilileri',
                '/federasyon-yetkili',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

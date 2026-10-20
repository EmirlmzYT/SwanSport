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

    final isStaff = access.isClubStaff;
    final isAccountant = access.isAccountant && !isStaff;
    final isParent = access.isParent &&
        ref.watch(featureEnabledProvider(FeatureFlags.parentHub));
    final isReferee = !profile.isClub &&
        access.isReferee &&
        ref.watch(featureEnabledProvider(FeatureFlags.refereeCockpit));
    final hasTraining = ref.watch(
      featureEnabledProvider(FeatureFlags.sportTrainingSessions),
    );
    final hasTurf =
        ref.watch(featureEnabledProvider(FeatureFlags.courtWaitlist)) ||
            ref.watch(featureEnabledProvider(FeatureFlags.turfDelegation));
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

            // 1. KULÜP YÖNETİMİ
            if (isStaff) ...[
              InkWell(
                onTap: () => open('/kulup-yonetim'),
                borderRadius: BorderRadius.circular(SwanRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.md),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(color: c.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(SwanSpace.sm),
                        decoration: BoxDecoration(
                          color: c.accentFill,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Icon(
                          Icons.space_dashboard_rounded,
                          color: c.onAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: SwanSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kulüp Yönetim Kokpiti',
                              style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                            ),
                            const SizedBox(height: SwanSpace.xs),
                            Text(
                              'Kadro, antrenman, aidat ve operasyonlar',
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: c.accent,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SwanSpace.md),
            ] else if (isAccountant) ...[
              entry(
                Icons.payments_rounded,
                'Mali İşler & Aidat',
                '/finans',
                subtitle: 'Kulüp aidat ve tahsilat takibi',
              ),
              const SizedBox(height: SwanSpace.sm),
            ],

            // 2. KİŞİSEL
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
            if(access.canUseTransferRequests && ref.watch(featureEnabledProvider(FeatureFlags.transferRequests)))
              entry(Icons.swap_horiz_rounded,'Transfer Talepleri','/transfer-talepleri'),
            entry(Icons.verified_user_outlined, 'Doğrulama', '/dogrulama'),
            if (hasTraining)
              entry(Icons.sports_rounded, 'Antrenmanlarım', '/antrenmanlarim'),
            if (isReferee)
              entry(
                Icons.sports_outlined,
                'Hakem Görevlerim',
                '/hakem/gorevler',
              ),
            if (hasDevReport)
              entry(
                Icons.insights_rounded,
                'Gelişim Raporu',
                '/gelisim-raporu',
              ),
            if (hasTurf)
              entry(
                Icons.sports_tennis_rounded,
                'Saha İşlemlerim',
                '/saha-islemlerim',
              ),
            if (isParent)
              entry(
                Icons.family_restroom_rounded,
                'Veli İşlem Merkezi',
                '/veli-izinleri',
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

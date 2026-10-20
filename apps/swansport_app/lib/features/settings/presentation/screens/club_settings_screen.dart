import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../../../app/widgets/swan_surface.dart';
import 'club_training_sports_sheet.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/home/home_quick_access.dart';
import '../../../../app/push/push.dart';
import '../../../../app/push/push_service.dart';
import '../../../../app/l10n/app_locale.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../clubs/presentation/club_edit_sheet.dart';
import '../../../clubs/presentation/club_create_sheet.dart';
import '../../../demo/demo_role.dart';
import '../../../auth/application/auth_controller.dart';

import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_shape.dart';

/// Persisted settings and shortcuts to existing services.
class ClubSettingsScreen extends ConsumerStatefulWidget {
  const ClubSettingsScreen({super.key});
  @override
  ConsumerState<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends ConsumerState<ClubSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final access = ref.watch(swanAccessProvider);
    final pendingApps =
        ref.watch(clubPendingApplicationsProvider).valueOrNull?.length ?? 0;

    return SwanScaffold(
      appBar: swanModuleAppBar(context, title: 'Kulüp Ayarları'),
      backgroundColor: c.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SwanSpace.lg,
              SwanSpace.md,
              SwanSpace.lg,
              SwanSpace.xl * 5,
            ),
            children: [
              // Kulüp Personeli için Kulüp Yönetimi ve Ayarları EN TEPEDE
              if (club != null && access.isClubStaff) ...[
                _group('Kulüp Yönetimi & Ayarları', [
                  _clubHeaderCard(club, access),
                  SwanActionCard(
                    title: 'Kulüp profilini düzenle',
                    icon: Icons.edit_outlined,
                    onTap: () => showClubEditSheet(context, club.id),
                  ),
                  SwanActionCard(
                    title: 'Kulüp branşlarını yönet',
                    icon: Icons.sports_rounded,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: c.bg,
                      builder: (_) => FractionallySizedBox(
                        heightFactor: .9,
                        child: ClubTrainingSportsSheet(clubId: club.id),
                      ),
                    ),
                  ),
                  SwanActionCard(
                    title: pendingApps > 0
                        ? 'Gelen Başvurular ($pendingApps yeni)'
                        : 'Gelen Başvurular',
                    icon: Icons.how_to_reg_rounded,
                    onTap: () => Navigator.pushNamed(context, '/basvurular'),
                  ),
                  _shortcut(
                      'Kadro & Sporcular', '/athletes', Icons.groups_outlined),
                  _shortcut(
                      'Aidat ve tahsilat', '/finans', Icons.payments_outlined),
                  SwanActionCard(
                    title: 'Kulüp Sayfasını Önizle',
                    icon: Icons.storefront_outlined,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/kulup-profil',
                      arguments: club.id,
                    ),
                  ),
                ]),
              ] else if (club == null && (access.coachLevel > 0 || access.isClubAdmin)) ...[
                _group('Kulüp İşlemleri', [
                  SwanActionCard(
                    title: 'Yeni Kulüp Kur',
                    icon: Icons.add_business_rounded,
                    onTap: () => showClubCreateSheet(context),
                  ),
                  _shortcut('Kulüpleri Keşfet / Başvur', '/kulupler',
                      Icons.search_rounded),
                ]),
              ],

              _group('Ana sayfa', [
                SwanActionCard(
                  title: 'Hızlı erişim',
                  subtitle: 'Kısayollarını seç, sırala veya gizle',
                  icon: Icons.dashboard_customize_outlined,
                  onTap: () => openQuickAccessSettings(context),
                ),
              ]),
              _group('Hesap & Güvenlik', [
                for (final action in [
                  ('Profilim', '/profil', Icons.person_outline),
                  (
                    'Lisans ve kimlik doğrulama',
                    '/dogrulama',
                    Icons.badge_outlined
                  ),
                  ('Veli bağlantısı', '/veli-bagla', Icons.family_restroom),
                  (
                    'Gizlilik ve engellenenler',
                    '/gizlilik',
                    Icons.shield_outlined
                  ),
                ])
                  _shortcut(action.$1, action.$2, action.$3),
              ]),

              _group('Görünüm, Dil ve Bildirimler', [
                DropdownButtonFormField<ThemeMode>(
                  initialValue: ref.watch(themeModeProvider),
                  decoration: const InputDecoration(labelText: 'Tema'),
                  items: [
                    for (final mode in ThemeMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(switch (mode) {
                          ThemeMode.system => 'Sistem',
                          ThemeMode.light => 'Açık',
                          ThemeMode.dark => 'Koyu'
                        }),
                      )
                  ],
                  onChanged: (mode) {
                    if (mode != null)
                      ref.read(themeModeProvider.notifier).set(mode);
                  },
                ),
                const SizedBox(height: SwanSpace.md),
                DropdownButtonFormField<AppLanguage>(
                  initialValue: ref.watch(appLocaleProvider),
                  decoration: const InputDecoration(labelText: 'Dil'),
                  items: [
                    for (final language in AppLanguage.values)
                      DropdownMenuItem(
                        value: language,
                        child: Text(language.nativeName),
                      )
                  ],
                  onChanged: (language) {
                    if (language != null)
                      ref
                          .read(appLocaleProvider.notifier)
                          .setLanguage(language);
                  },
                ),
                const _PushToggleRow(),
                _shortcut(
                    'Bildirimler', '/bildirimler', Icons.notifications_outlined),
              ]),

              _group('Destek ve Oturum', [
                if (access.isPlatformAdmin) ...[
                  _shortcut('Onay paneli', '/onay-paneli',
                      Icons.admin_panel_settings_outlined),
                  _shortcut(
                      'Haber kaynakları', '/haber-kaynaklari', Icons.rss_feed),
                ],
                _shortcut('Yardım', '/yardim', Icons.help_outline),
                _shortcut('Destek', '/destek', Icons.support_agent),
                if (ref.watch(debugToolsEnabledProvider))
                  _shortcut(
                      'Demo rolleri', '/demo-rol', Icons.science_outlined),
                SwanActionCard(
                    title: 'Hesaptan Çıkış Yap',
                    icon: Icons.logout,
                    onTap: _signOut),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _clubHeaderCard(ClubRef club, SwanAccess access) {
    final c = context.swan;
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.md),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.accent.withValues(alpha: 0.2),
            child: Icon(Icons.shield_rounded, color: c.accent, size: 22),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.body(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  access.isClubAdmin ? 'Kulüp Yöneticisi' : 'Kulüp Antrenörü',
                  style: SwanType.caption(c.accent, w: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) => SwanSurface(child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: SwanType.h3(context.swan.ink)),
      const SizedBox(height: SwanSpace.md), ...children,
    ]));
  Widget _shortcut(String title, String route, IconData icon) => SwanActionCard(
    title: title, icon: icon, onTap: () => Navigator.pushNamed(context, route));

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text(
          'Oturumun kapatılacak. Tekrar giriş yapman gerekecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (ref.read(isSupabaseEnabledProvider))
        await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Çıkış yapılamadı: $e')));
      return;
    }
    if (mounted) {
      await Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }
}

/// Gerçek push anahtarı — tarayıcı aboneliğini ve veritabanı kaydını yönetir.
class _PushToggleRow extends ConsumerWidget {
  const _PushToggleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? context.swan.ink : SwanPalette.light.ink;
    final textMuted =
        isDark ? context.swan.inkMuted : context.swan.inkMuted;
    final surfHigh = isDark ? context.swan.surfaceAlt : context.swan.surfaceAlt;
    final on = ref.watch(pushEnabledProvider).valueOrNull ?? false;

    return Padding(
      padding: const EdgeInsets.all(SwanSpace.md),
      child: Row(
        children: [
          Container(
            width: SwanSpace.xl + SwanSpace.md,
            height: SwanSpace.xl + SwanSpace.md,
            decoration: BoxDecoration(
              color: surfHigh,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Icon(
              on
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_rounded,
              size: SwanSpace.lg + SwanSpace.xs,
              color: context.swan.accent,
            ),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Telefon Bildirimleri',
                  style: SwanType.bodySm(textPrimary, w: FontWeight.w600),
                ),
                Text(
                  on
                      ? 'Uygulama kapalıyken de anlık bildirim'
                      : 'Mesaj ve antrenman çağrıları telefonuna düşsün',
                  style: SwanType.caption(textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeTrackColor: context.swan.accent,
            activeThumbColor: context.swan.onAccent,
            onChanged: !pushSupported
                ? null
                : (v) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      if (v) {
                        await enablePush(ref);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Bildirimler açıldı'),
                            backgroundColor: context.swan.accent,
                          ),
                        );
                      } else {
                        await disablePush(ref);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Bildirimler kapatıldı'),
                            backgroundColor: context.swan.inkMuted,
                          ),
                        );
                      }
                    } on PushException catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            switch (e.reason) {
                              PushFailure.denied =>
                                'Bildirim izni reddedilmiş. Tarayıcı ayarlarından izin ver.',
                              PushFailure.unsupported =>
                                'Bu tarayıcı bildirim desteklemiyor.',
                              PushFailure.failed => 'Açılamadı, tekrar dene.',
                              PushFailure.apnsUnavailable => 'iOS APNs kaydı hazır değil. İmza ve Firebase yapılandırmasını kontrol et.',
                            },
                          ),
                          backgroundColor: SwanPalette.light.danger,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}

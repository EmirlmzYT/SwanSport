import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/push/push.dart';
import '../../../../app/push/push_service.dart';
import '../../../../app/l10n/app_locale.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../clubs/presentation/club_edit_sheet.dart';
import '../../../demo/demo_role.dart';
import '../../../auth/application/auth_controller.dart';

import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';

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
    return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(title: const Text('Ayarlar')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      for (final action in [
                        ('Profilim', '/profil', Icons.person_outline),
                        (
                          'Lisans ve kimlik doğrulama',
                          '/dogrulama',
                          Icons.badge_outlined
                        ),
                        (
                          'Veli bağlantısı',
                          '/veli-bagla',
                          Icons.family_restroom
                        ),
                        (
                          'Gizlilik ve engellenenler',
                          '/gizlilik',
                          Icons.shield_outlined
                        ),
                      ])
                        _shortcut(action.$1, action.$2, action.$3),
                      const Divider(),
                      Text('Görünüm ve dil', style: SwanType.h3(c.ink)),
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
                                  }))
                          ],
                          onChanged: (mode) {
                            if (mode != null)
                              ref.read(themeModeProvider.notifier).set(mode);
                          }),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AppLanguage>(
                          initialValue: ref.watch(appLocaleProvider),
                          decoration: const InputDecoration(labelText: 'Dil'),
                          items: [
                            for (final language in AppLanguage.values)
                              DropdownMenuItem(
                                  value: language,
                                  child: Text(language.nativeName))
                          ],
                          onChanged: (language) {
                            if (language != null)
                              ref
                                  .read(appLocaleProvider.notifier)
                                  .setLanguage(language);
                          }),
                      const SizedBox(height: 16),
                      const _PushToggleRow(),
                      _shortcut('Bildirimler', '/bildirimler',
                          Icons.notifications_outlined),
                      if (club != null && access.isClubStaff) ...[
                        const Divider(),
                        Text('Kulüp yönetimi', style: SwanType.h3(c.ink)),
                        ListTile(
                            leading: const Icon(Icons.edit_outlined),
                            title: const Text('Kulüp profilini düzenle'),
                            onTap: () => showClubEditSheet(context, club.id)),
                        ListTile(
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(club.name),
                            onTap: () => Navigator.pushNamed(
                                context, '/kulup-profil',
                                arguments: club.id)),
                        _shortcut('Aidat ve tahsilat', '/finans',
                            Icons.payments_outlined),
                      ],
                      if (access.isPlatformAdmin) ...[
                        _shortcut('Onay paneli', '/onay-paneli',
                            Icons.admin_panel_settings_outlined),
                        _shortcut('Haber kaynakları', '/haber-kaynaklari',
                            Icons.rss_feed),
                      ],
                      const Divider(),
                      _shortcut('Yardım', '/yardim', Icons.help_outline),
                      _shortcut('Destek', '/destek', Icons.support_agent),
                      if (ref.watch(debugToolsEnabledProvider))
                        _shortcut('Demo rolleri', '/demo-rol',
                            Icons.science_outlined),
                      ListTile(
                          leading: Icon(Icons.logout, color: c.danger),
                          title: const Text('Hesaptan Çıkış Yap'),
                          onTap: _signOut),
                    ]))),
        bottomNavigationBar: const SwanBottomNav());
  }

  Widget _shortcut(String title, String route, IconData icon) => ListTile(
      title: Text(title),
      leading: Icon(icon),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, route));

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
        isDark ? const Color(0xFFD6E3FA) : SwanPalette.light.ink;
    final textMuted =
        isDark ? const Color(0xFF869491) : SwanColors.textSecondary;
    final surfHigh = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFEAEFF8);
    final on = ref.watch(pushEnabledProvider).valueOrNull ?? false;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: surfHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              on
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_rounded,
              size: 20,
              color: kTeal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Telefon Bildirimleri',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  on
                      ? 'Uygulama kapalıyken de anlık bildirim'
                      : 'Mesaj ve antrenman çağrıları telefonuna düşsün',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeTrackColor: kTeal,
            activeThumbColor: const Color(0xFF003734),
            onChanged: !pushSupported
                ? null
                : (v) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      if (v) {
                        await enablePush(ref);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Bildirimler açıldı'),
                            backgroundColor: kTeal,
                          ),
                        );
                      } else {
                        await disablePush(ref);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Bildirimler kapatıldı'),
                            backgroundColor: SwanColors.textSecondary,
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

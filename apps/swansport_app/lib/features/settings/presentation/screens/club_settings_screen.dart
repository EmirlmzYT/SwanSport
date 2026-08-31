import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/push/push.dart';
import '../../../../app/push/push_service.dart';
import '../../../../app/widgets/premium.dart';
import '../../../demo/demo_role.dart';
import '../../../social/presentation/edit_profile_sheet.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Ayarlar.
///
/// Eskiden satırların hiçbiri bir yere gitmiyordu ve bildirim anahtarı yalnızca
/// ekranda duruyordu (gerçek push sistemine bağlı değildi). Artık her satırın
/// bir karşılığı var; karşılığı olmayan hiçbir şey burada durmuyor.
class ClubSettingsScreen extends ConsumerStatefulWidget {
  const ClubSettingsScreen({super.key});

  @override
  ConsumerState<ClubSettingsScreen> createState() => _ClubSettingsScreenState();
}

class _ClubSettingsScreenState extends ConsumerState<ClubSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final isAdmin = ref.watch(effectiveIsPlatformAdminProvider);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final me = uid == null
        ? null
        : ref.watch(socialProfileProvider(uid)).valueOrNull;

    // Kulüp bölümü yalnızca kulüpte görev alanlara gösterilir; sporcu ve veli
    // için anlamsız satırlar olurdu.
    final isStaff = profile?.role == 'club_admin' ||
        profile?.role == 'coach' ||
        profile?.role == 'official';

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
              children: [
                Text('Ayarlar', style: SwanType.h2(ink)),
                const SizedBox(height: 16),

                // ------------------------------- hesap
                _group(isDark, [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: me == null
                        ? null
                        : () async {
                            final saved =
                                await showEditProfileSheet(context, me);
                            if (saved == true) {
                              ref.invalidate(socialProfileProvider(uid!));
                              ref.invalidate(currentProfileProvider);
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        GradientAvatar(
                            initials: profile?.initials ?? '?',
                            size: 48,
                            radius: 16),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile?.fullName ?? 'Kullanıcı',
                                  style: SwanType.body(ink, w: FontWeight.w800)),
                              Text(
                                  '${_roleLabel(profile?.role)}'
                                  '${club == null ? '' : ' · ${club.name}'}',
                                  style: SwanType.caption(SwanColors.textSecondary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_rounded,
                            size: 17, color: SwanColors.textSecondary),
                      ]),
                    ),
                  ),
                ]),

                _label('HESAP', ink),
                _group(isDark, [
                  _row(isDark, Icons.person_rounded, 'Profilim',
                      onTap: uid == null
                          ? null
                          : () => Navigator.pushNamed(context, '/profil',
                              arguments: uid)),
                  _sep(isDark),
                  _row(isDark, Icons.verified_user_rounded, 'Doğrulama',
                      sub: 'Antrenör/sporcu kimliğini onaylat',
                      onTap: () =>
                          Navigator.pushNamed(context, '/dogrulama')),
                  _sep(isDark),
                  _row(isDark, Icons.receipt_long_rounded, 'Aidatlarım',
                      onTap: () =>
                          Navigator.pushNamed(context, '/aidatlarim')),
                  _sep(isDark),
                  _row(isDark, Icons.family_restroom_rounded, 'Veli bağlantısı',
                      sub: 'Davet koduyla sporcuna bağlan',
                      onTap: () =>
                          Navigator.pushNamed(context, '/veli-bagla')),
                ]),

                // ------------------------------- bildirimler
                _label('BİLDİRİMLER', ink),
                _group(isDark, [
                  const _PushToggleRow(),
                  if (!pushSupported)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                          'Bu tarayıcı bildirim desteklemiyor. iPhone '
                          'kullanıyorsan uygulamayı ana ekrana ekleyip oradan aç.',
                          style: SwanType.caption(SwanColors.textSecondary)),
                    ),
                ]),

                // ------------------------------- kulüp
                if (isStaff && club != null) ...[
                  _label('KULÜP', ink),
                  _group(isDark, [
                    _row(isDark, Icons.badge_rounded, 'Kulüp profili',
                        sub: club.name,
                        onTap: () => Navigator.pushNamed(
                            context, '/kulup-profil',
                            arguments: club.id)),
                    _sep(isDark),
                    _row(isDark, Icons.tune_rounded, 'Yapılandırma',
                        sub: 'Kimlik, roller, sezonlar',
                        onTap: () =>
                            Navigator.pushNamed(context, '/configuration')),
                    _sep(isDark),
                    _row(isDark, Icons.payments_rounded, 'Aidat & tahsilat',
                        onTap: () => Navigator.pushNamed(context, '/finans')),
                  ]),
                ],

                // ------------------------------- platform
                if (isAdmin) ...[
                  _label('PLATFORM', ink),
                  _group(isDark, [
                    _row(isDark, Icons.admin_panel_settings_rounded,
                        'Yönetim paneli',
                        onTap: () =>
                            Navigator.pushNamed(context, '/onay-paneli')),
                    _sep(isDark),
                    _row(isDark, Icons.rss_feed_rounded, 'Haber kaynakları',
                        onTap: () => Navigator.pushNamed(
                            context, '/haber-kaynaklari')),
                  ]),
                ],

                // ------------------------------- gizlilik & hesap
                _label('GİZLİLİK', ink),
                _group(isDark, [
                  _row(isDark, Icons.shield_outlined,
                      'Gizlilik ve engellenenler',
                      sub: 'Engelledikleri, veri ve hesap silme',
                      onTap: () => Navigator.pushNamed(context, '/gizlilik')),
                  if (ref.watch(debugToolsEnabledProvider)) ...[
                    _sep(isDark),
                    _row(isDark, Icons.theater_comedy_outlined, 'Demo rolleri',
                        sub: 'Yalnızca geliştirme derlemesi',
                        onTap: () =>
                            Navigator.pushNamed(context, '/demo-rol')),
                  ],
                ]),

                const SizedBox(height: 24),
                Center(
                  child: Text('SwanSport · sürüm 1.0.5',
                      style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: SwanPalette.light.danger
                                .withValues(alpha: .35)),
                      ),
                      child: Text('Çıkış Yap',
                          style: SwanType.bodySm(SwanPalette.light.danger, w: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text('Oturumun kapatılacak. Tekrar giriş yapman '
            'gerekecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Çıkış yap')),
        ],
      ),
    );
    if (ok != true) return;
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  String _roleLabel(String? role) => switch (role) {
        'club_admin' => 'Yönetici',
        'coach' => 'Antrenör',
        'athlete' => 'Sporcu',
        'parent' => 'Veli',
        'official' => 'Görevli',
        _ => 'Üye',
      };

  Widget _label(String t, Color ink) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(t,
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
      );

  Widget _group(bool isDark, List<Widget> children) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(bool isDark, IconData icon, String label,
      {String? sub, VoidCallback? onTap}) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(icon, size: 20, color: kTeal),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: SwanType.bodySm(ink, w: FontWeight.w600)),
                if (sub != null)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: SwanColors.textSecondary, size: 20),
        ]),
      ),
    );
  }

  Widget _sep(bool isDark) => Divider(
      height: 1,
      color: isDark ? SwanPalette.dark.line : SwanPalette.light.line);
}

/// Gerçek push anahtarı — tarayıcı aboneliğini ve veritabanı kaydını yönetir.
class _PushToggleRow extends ConsumerWidget {
  const _PushToggleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final on = ref.watch(pushEnabledProvider).valueOrNull ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(on ? Icons.notifications_active_rounded : Icons.notifications_rounded,
            size: 20, color: kTeal),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Telefon bildirimleri',
                  style: SwanType.bodySm(ink, w: FontWeight.w600)),
              Text(
                  on
                      ? 'Uygulama kapalıyken de haber verilir'
                      : 'Mesaj ve duyurular telefonuna düşsün',
                  style: SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
        ),
        Switch(
          value: on,
          activeTrackColor: kTeal,
          onChanged: !pushSupported
              ? null
              : (v) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    if (v) {
                      await enablePush(ref);
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Bildirimler açıldı'),
                          backgroundColor: kTeal));
                    } else {
                      await disablePush(ref);
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Bildirimler kapatıldı'),
                          backgroundColor: SwanColors.textSecondary));
                    }
                  } on PushException catch (e) {
                    messenger.showSnackBar(SnackBar(
                      content: Text(switch (e.reason) {
                        PushFailure.denied =>
                          'Bildirim izni reddedilmiş. Tarayıcı ayarlarından izin ver.',
                        PushFailure.unsupported =>
                          'Bu tarayıcı bildirim desteklemiyor.',
                        PushFailure.failed => 'Açılamadı, tekrar dene.',
                      }),
                      backgroundColor: SwanPalette.light.danger,
                    ));
                  }
                },
        ),
      ]),
    );
  }
}

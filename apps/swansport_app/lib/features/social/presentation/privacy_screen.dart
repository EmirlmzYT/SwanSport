import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';
import '../../auth/application/auth_controller.dart';

/// Profil Güvenlik Merkezi — rol tabanlı yetkiler, kimlik doğrulama, gizlilik ve hesap (Stitch Calm Athletic Modernism).
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _twoFactorEnabled = true;
  bool _biometricsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final isDark = c.isDark;
    final blocks = ref.watch(myBlocksProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final club = ref.watch(activeClubProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 132),
              children: [
                SwanPageHeader(
                  title: 'Profil Güvenlik Merkezi',
                  subtitle: 'Rol tabanlı yetkiler, biyometri ve gizlilik',
                  onBack: () => Navigator.maybePop(context),
                  actions: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shield_rounded, color: c.accent, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.md),

                // 1. Identity & Role Card
                _buildIdentityCard(c, user, club),
                const SizedBox(height: SwanSpace.lg),

                // 2. Role-Based Permissions & Access (Rol Tabanlı Yetki & İzinler)
                _buildRolePermissionsSection(c),
                const SizedBox(height: SwanSpace.lg),

                // 3. Authentication & Security (Kimlik Doğrulama & Güvenlik)
                _buildAuthenticationSection(c),
                const SizedBox(height: SwanSpace.lg),

                // 4. Mention Policy (Etiketlenme İzni)
                Text('Etiketlenme', style: SwanType.h3(c.ink)),
                const SizedBox(height: SwanSpace.xs),
                Text(
                  'Seni kim gönderilerde etiketleyebilir. Engellediğin kişiler hiçbir durumda etiketleyemez.',
                  style: SwanType.caption(c.inkMuted),
                ),
                const SizedBox(height: SwanSpace.sm),
                _MentionPolicyPicker(isDark: isDark),
                const SizedBox(height: SwanSpace.lg),

                // 5. Blocked Users (Engellenenler)
                Text('Engellenenler', style: SwanType.h3(c.ink)),
                const SizedBox(height: SwanSpace.xs),
                Text(
                  'Engellediğin kişiler senin profilini ve gönderilerini göremez.',
                  style: SwanType.caption(c.inkMuted),
                ),
                const SizedBox(height: SwanSpace.sm),
                blocks.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(SwanSpace.md),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          border: Border.all(color: c.line),
                        ),
                        child: Text(
                          'Engellediğin kimse bulunmuyor.',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      );
                    }
                    return Column(
                      children: list.map((b) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: SwanSpace.sm),
                          padding: const EdgeInsets.all(SwanSpace.md),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                            border: Border.all(color: c.line),
                          ),
                          child: Row(
                            children: [
                              GradientAvatar(
                                initials: b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                                size: 38,
                              ),
                              const SizedBox(width: SwanSpace.sm),
                              Expanded(
                                child: Text(
                                  b.name,
                                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref.read(moderationServiceProvider).unblock(b.id);
                                  ref.invalidate(myBlocksProvider);
                                },
                                child: Text(
                                  'Engeli Kaldır',
                                  style: SwanType.caption(c.accent, w: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: SwanSpace.xl),

                // 6. Danger Zone (Hesabı Sil)
                Container(
                  padding: const EdgeInsets.all(SwanSpace.md),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: SwanPalette.light.danger.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.delete_outline_rounded, color: SwanPalette.light.danger, size: 20),
                      ),
                      const SizedBox(width: SwanSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hesabı Sil',
                              style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                            ),
                            Text(
                              'Verilerin kalıcı olarak temizlenir',
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _deleteAccount,
                        style: TextButton.styleFrom(
                          foregroundColor: SwanPalette.light.danger,
                        ),
                        child: Text(
                          'Sil',
                          style: SwanType.caption(SwanPalette.light.danger, w: FontWeight.w800),
                        ),
                      ),
                    ],
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

  Widget _buildIdentityCard(SwanPalette c, User? user, ClubRef? club) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Row
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.line),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : 'Z',
                      style: SwanType.h2(c.accent),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.accentFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user?.userMetadata?['name'] as String? ?? 'Zeynep Yılmaz',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.body(c.ink, w: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              Text('Aktif', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${club?.name ?? "Marmara Okçuluk Kulübü"} • U18',
                      style: SwanType.caption(c.inkMuted),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.supervised_user_circle_rounded, size: 14, color: c.accent),
                        const SizedBox(width: 3),
                        Text('Veli: Ayşe Yılmaz (Bağlı)', style: SwanType.caption(c.ink)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),

          // Role Switcher Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: SwanSpace.sm),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 6),
                    Text('Lisanslı Sporcu Rolü', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/role-select'),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.line),
                    ),
                    child: Text('Rol Değiştir', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.md),

          // Security Score Gauge
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: .15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '%92',
                    style: SwanType.bodySm(c.accent, w: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: SwanSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Güvenlik Seviyesi', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 15, color: c.accent),
                        ],
                      ),
                      Text('Yüksek Koruma • 2FA Devrede', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ),
                Icon(Icons.security_update_good_rounded, color: c.accent, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolePermissionsSection(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.key_rounded, color: c.accent, size: 18),
                  const SizedBox(width: 5),
                  Text('Rol Tabanlı Yetki & İzinler', style: SwanType.h3(c.ink)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Kulüp Onaylı', style: SwanType.caption(c.accent, w: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),

          // 1. Poligon ve Saha Girişi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Icon(Icons.sensor_door_rounded, color: c.accent, size: 20),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Poligon ve Saha Girişi', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                    Text('Açık Saha & 18m Kapalı Salon', style: SwanType.caption(c.inkMuted)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Turnike & Biyometri Senkron', style: SwanType.caption(c.ink, w: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Turnike QR Kodu hazırlandı.')),
                  );
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.accentFill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('QR Kod', style: SwanType.caption(Colors.white, w: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // 2. Skor Kayıt Yetkisi
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Icon(Icons.scoreboard_rounded, color: c.inkMuted, size: 20),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Antrenman Skor Kayıt Yetkisi', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                    Text('Başantrenör teyidi zorunludur', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: c.inkMuted),
                    const SizedBox(width: 3),
                    Text('Kilitli', style: SwanType.caption(c.inkMuted, w: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // 3. Mali & Aidat Yetki Sınırı
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Icon(Icons.payments_rounded, color: c.accent, size: 20),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mali & Aidat Yetki Sınırı', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                    Text('Kişisel limit: ₺2.500 / ay • Veli onayı beklenir', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.family_restroom_rounded, size: 13, color: c.accent),
                    const SizedBox(width: 3),
                    Text('Veliye Bağlı', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationSection(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded, color: c.accent, size: 18),
              const SizedBox(width: 5),
              Text('Kimlik Doğrulama & Güvenlik', style: SwanType.h3(c.ink)),
            ],
          ),
          const SizedBox(height: SwanSpace.md),

          // 2FA Toggle
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Icon(Icons.phonelink_lock_rounded, color: c.accent, size: 20),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('İki Faktörlü Doğrulama (2FA)', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                    Text('SMS & Authenticator Uygulaması', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _twoFactorEnabled,
                activeTrackColor: c.accent,
                onChanged: (v) => setState(() => _twoFactorEnabled = v),
              ),
            ],
          ),
          const Divider(height: 24),

          // Biometrics Toggle
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Icon(Icons.fingerprint_rounded, color: c.accent, size: 20),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Biyometrik Giriş', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                    Text('Face ID & Parmak İzi', style: SwanType.caption(c.inkMuted)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _biometricsEnabled,
                activeTrackColor: c.accent,
                onChanged: (v) => setState(() => _biometricsEnabled = v),
              ),
            ],
          ),
          const Divider(height: 24),

          // Password change
          InkWell(
            onTap: _changePassword,
            borderRadius: BorderRadius.circular(SwanRadius.sm),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Icon(Icons.lock_reset_rounded, color: c.accent, size: 20),
                ),
                const SizedBox(width: SwanSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Şifreyi Değiştir', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                      Text('Yeni ve güçlü bir parola belirle', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.swan.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Yeni Şifre', style: SwanType.h3(context.swan.ink)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: SwanType.bodySm(context.swan.ink),
          decoration: const InputDecoration(
            hintText: 'En az 6 karakter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: SwanType.bodySm(context.swan.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kaydet', style: SwanType.bodySm(context.swan.accent, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final done = await ref.read(authControllerProvider.notifier).updatePassword(ctrl.text);
    if (!mounted) return;
    final msg = ref.read(authControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(done ? 'Şifren güncellendi' : (msg ?? 'Güncellenemedi')),
        backgroundColor: done ? context.swan.accent : SwanPalette.light.danger,
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.swan.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Emin misin?', style: SwanType.h3(context.swan.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu işlem geri alınamaz. Onaylamak için aşağıya “SİL” yaz.',
              style: SwanType.bodySm(context.swan.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: SwanType.bodySm(context.swan.ink, w: FontWeight.w800),
              decoration: const InputDecoration(hintText: 'SİL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: SwanType.bodySm(context.swan.inkMuted, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hesabımı sil', style: SwanType.bodySm(SwanPalette.light.danger, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (confirm.text.trim().toUpperCase() != 'SİL') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Onay metni eşleşmedi'),
            backgroundColor: SwanPalette.light.warning,
          ),
        );
      }
      return;
    }

    try {
      await ref.read(moderationServiceProvider).deleteMyAccount();
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        unawaited(Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Silinemedi: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
      }
    }
  }
}

/// Etiketlenme izni seçici.
class _MentionPolicyPicker extends ConsumerStatefulWidget {
  const _MentionPolicyPicker({required this.isDark});

  final bool isDark;

  @override
  ConsumerState<_MentionPolicyPicker> createState() => _MentionPolicyPickerState();
}

class _MentionPolicyPickerState extends ConsumerState<_MentionPolicyPicker> {
  MentionPolicy? _value;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await Supabase.instance.client
          .from('profiles')
          .select('mention_policy')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _value = mentionPolicyFrom(row?['mention_policy'] as String?));
    } catch (_) {
      if (mounted) setState(() => _value = null);
    }
  }

  Future<void> _set(MentionPolicy p) async {
    setState(() => _busy = true);
    try {
      await ref.read(socialShareServiceProvider).setPrivacy(mention: p);
      if (mounted) setState(() => _value = p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    if (_value == null) return const SizedBox.shrink();

    return Column(
      children: [
        for (final p in MentionPolicy.values)
          GestureDetector(
            onTap: _busy || _value == p ? null : () => _set(p),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _value == p ? c.accent : c.line,
                  width: _value == p ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _value == p ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: _value == p ? c.accent : c.inkMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(mentionPolicyLabel(p), style: SwanType.bodySm(c.ink)),
                  ),
                  if (_busy && _value != p)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

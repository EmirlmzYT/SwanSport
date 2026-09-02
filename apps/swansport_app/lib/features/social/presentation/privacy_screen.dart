import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../auth/application/auth_controller.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Gizlilik ve hesap — engellenenler, şifre değiştirme, hesap silme.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final blocks = ref.watch(myBlocksProvider);

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
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Gizlilik ve Hesap',
                      style: SwanType.h2(ink)),
                ]),
                const SizedBox(height: 22),

                // --- Şifre ---
                Text('Güvenlik', style: SwanType.h3(ink)),
                const SizedBox(height: 10),
                _tile(isDark, Icons.lock_reset_rounded, 'Şifreyi değiştir',
                    'Yeni bir şifre belirle', _changePassword),
                const SizedBox(height: 22),

                // --- Etiketlenme ---
                //
                // Kapatılan kişi etiket seçicisinde **hiç görünmüyor**;
                // "bu kişi etiketlenmeyi kapatmış" diye bir mesaj da yok,
                // o ayarı sızdırırdı.
                Text('Etiketlenme', style: SwanType.h3(ink)),
                const SizedBox(height: 6),
                Text(
                  'Seni kim gönderilerde etiketleyebilir. Engellediğin '
                  'kişiler her durumda etiketleyemez.',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),
                const SizedBox(height: 10),
                _MentionPolicyPicker(isDark: isDark),
                const SizedBox(height: 22),

                // --- Engellenenler ---
                Text('Engellenenler', style: SwanType.h3(ink)),
                const SizedBox(height: 10),
                blocks.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return Text('Kimseyi engellemedin.',
                          style: SwanType.caption(SwanColors.textSecondary));
                    }
                    return Column(
                      children: list.map((b) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: line),
                          ),
                          child: Row(children: [
                            GradientAvatar(
                                initials: b.name.isNotEmpty
                                    ? b.name[0].toUpperCase()
                                    : '?',
                                size: 38),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(b.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SwanType.bodySm(ink, w: FontWeight.w700)),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await ref
                                    .read(moderationServiceProvider)
                                    .unblock(b.id);
                                ref.invalidate(myBlocksProvider);
                                ref.invalidate(hiddenProfilesProvider);
                              },
                              child: Text('Kaldır',
                                  style:
                                      SwanType.caption(kTeal, w: FontWeight.w800)),
                            ),
                          ]),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 26),

                // --- Hesabı sil ---
                Text('Hesap', style: SwanType.h3(ink)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: SwanPalette.light.danger.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: SwanPalette.light.danger.withValues(alpha: .35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hesabını sil',
                          style: SwanType.bodySm(SwanPalette.light.danger, w: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(
                          'Hesabın ve tüm içeriğin (gönderiler, yorumlar, '
                          'mesajlar) kalıcı olarak silinir. Bu işlem geri '
                          'alınamaz.',
                          style: SwanType.caption(SwanColors.textSecondary)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _deleteAccount,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: SwanPalette.light.danger,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text('Hesabımı Sil',
                              style:
                                  SwanType.bodySm(Colors.white, w: FontWeight.w800)),
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

  Widget _tile(bool isDark, IconData icon, String title, String sub,
      VoidCallback onTap) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: kTeal.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: kTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                Text(sub,
                    style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }

  Future<void> _changePassword() async {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Yeni şifre', style: SwanType.h3(ink)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: SwanType.bodySm(ink, w: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'En az 6 karakter',
            hintStyle:
                SwanType.bodySm(SwanColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kaydet', style: SwanType.bodySm(kTeal, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final done = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(ctrl.text);
    if (!mounted) return;
    final msg = ref.read(authControllerProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(done ? 'Şifren güncellendi' : (msg ?? 'Güncellenemedi')),
      backgroundColor: done ? kTeal : SwanPalette.light.danger,
    ));
  }

  Future<void> _deleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final confirm = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Emin misin?', style: SwanType.h3(ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bu işlem geri alınamaz. Onaylamak için aşağıya '
                '“SİL” yaz.',
                style:
                    SwanType.bodySm(SwanColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: SwanType.bodySm(ink, w: FontWeight.w800),
              decoration: const InputDecoration(hintText: 'SİL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hesabımı sil',
                style: SwanType.bodySm(SwanPalette.light.danger, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (confirm.text.trim().toUpperCase() != 'SİL') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Onay metni eşleşmedi'),
            backgroundColor: SwanPalette.light.warning));
      }
      return;
    }

    try {
      await ref.read(moderationServiceProvider).deleteMyAccount();
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Silinemedi: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
  }
}

/// Etiketlenme izni seçici.
///
/// Mevcut değer profilden okunuyor; sunucu `set_social_privacy` ile
/// güncelleniyor. İyimser değil: sunucu onaylamadan seçim değişmiyor, çünkü
/// bu bir gizlilik ayarı ve "değişti sandım ama değişmemiş" en kötü durum.
class _MentionPolicyPicker extends ConsumerStatefulWidget {
  const _MentionPolicyPicker({required this.isDark});

  final bool isDark;

  @override
  ConsumerState<_MentionPolicyPicker> createState() =>
      _MentionPolicyPickerState();
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
      setState(() =>
          _value = mentionPolicyFrom(row?['mention_policy'] as String?));
    } catch (_) {
      // 0062 çalıştırılmadıysa sütun yok. Seçici çizilmiyor; hata
      // göstermek kullanıcıya yapabileceği bir şey söylemiyor.
      if (mounted) setState(() => _value = null);
    }
  }

  Future<void> _set(MentionPolicy p) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(socialShareServiceProvider)
          .setPrivacy(mention: p);
      if (mounted) setState(() => _value = p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.isDark ? SwanPalette.dark : SwanPalette.light;
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
                    width: _value == p ? 1.5 : 1),
              ),
              child: Row(children: [
                Icon(
                    _value == p
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: _value == p ? c.accent : c.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(mentionPolicyLabel(p),
                      style: SwanType.bodySm(c.ink)),
                ),
                if (_busy && _value != p)
                  const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
            ),
          ),
      ],
    );
  }
}

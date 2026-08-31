import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../auth/application/auth_controller.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

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
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
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
                      style: sora(21, FontWeight.w800, ink)),
                ]),
                const SizedBox(height: 22),

                // --- Şifre ---
                Text('GÜVENLİK',
                    style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                        ls: 1.2)),
                const SizedBox(height: 10),
                _tile(isDark, Icons.lock_reset_rounded, 'Şifreyi değiştir',
                    'Yeni bir şifre belirle', _changePassword),
                const SizedBox(height: 22),

                // --- Engellenenler ---
                Text('ENGELLENENLER',
                    style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                        ls: 1.2)),
                const SizedBox(height: 10),
                blocks.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return Text('Kimseyi engellemedin.',
                          style: jakarta(
                              12.5, FontWeight.w500, SwanColors.textSecondary));
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
                                  style: jakarta(13.5, FontWeight.w700, ink)),
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
                                      jakarta(12.5, FontWeight.w800, kTeal)),
                            ),
                          ]),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 26),

                // --- Hesabı sil ---
                Text('HESAP',
                    style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                        ls: 1.2)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFF43F5E).withValues(alpha: .35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hesabını sil',
                          style: jakarta(
                              14, FontWeight.w800, const Color(0xFFF43F5E))),
                      const SizedBox(height: 5),
                      Text(
                          'Hesabın ve tüm içeriğin (gönderiler, yorumlar, '
                          'mesajlar) kalıcı olarak silinir. Bu işlem geri '
                          'alınamaz.',
                          style: jakarta(
                              12, FontWeight.w500, SwanColors.textSecondary)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _deleteAccount,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text('Hesabımı Sil',
                              style:
                                  jakarta(13.5, FontWeight.w800, Colors.white)),
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
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
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
                Text(title, style: jakarta(13.5, FontWeight.w700, ink)),
                Text(sub,
                    style: jakarta(
                        11.5, FontWeight.w500, SwanColors.textSecondary)),
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
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Yeni şifre', style: sora(17, FontWeight.w800, ink)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: jakarta(14, FontWeight.w600, ink),
          decoration: InputDecoration(
            hintText: 'En az 6 karakter',
            hintStyle:
                jakarta(13, FontWeight.w500, SwanColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    jakarta(13, FontWeight.w700, SwanColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kaydet', style: jakarta(13, FontWeight.w800, kTeal)),
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
      backgroundColor: done ? kTeal : const Color(0xFFF43F5E),
    ));
  }

  Future<void> _deleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final confirm = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Emin misin?', style: sora(17, FontWeight.w800, ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bu işlem geri alınamaz. Onaylamak için aşağıya '
                '“SİL” yaz.',
                style:
                    jakarta(13, FontWeight.w500, SwanColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: jakarta(14, FontWeight.w800, ink),
              decoration: const InputDecoration(hintText: 'SİL'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    jakarta(13, FontWeight.w700, SwanColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hesabımı sil',
                style: jakarta(13, FontWeight.w800, const Color(0xFFF43F5E))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (confirm.text.trim().toUpperCase() != 'SİL') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Onay metni eşleşmedi'),
            backgroundColor: Color(0xFFD9860B)));
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
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }
}

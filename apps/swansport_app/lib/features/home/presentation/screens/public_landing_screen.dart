import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../auth/application/auth_controller.dart';

/// Herkese açık karşılama ekranı — premium tasarım (v3).
///
/// Oturum durumuna duyarlı: giriş yapılmışsa doğrudan panele geçirir,
/// yapılmamışsa giriş/kayıt sunar.
class PublicLandingScreen extends ConsumerWidget {
  const PublicLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final enabled = ref.watch(isSupabaseEnabledProvider);
    final signedIn =
        enabled && Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              children: [
                // Marka
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kTealBright, kTeal, kTealDeep],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: kTeal.withValues(alpha: 0.34),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('S',
                        style: sora(26, FontWeight.w800, Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Text('SwanSport', style: sora(20, FontWeight.w800, ink)),
                ]),
                const SizedBox(height: 32),

                Text('Spor kulübünüzün\ndijital merkezi.',
                    style: sora(32, FontWeight.w800, ink)),
                const SizedBox(height: 12),
                Text(
                  'Kadro, antrenman, yoklama, aidat ve sağlık takibi tek '
                  'platformda. Roller belgeyle doğrulanır — kim ne yapabilir, '
                  'net.',
                  style:
                      jakarta(14.5, FontWeight.w500, SwanColors.textSecondary),
                ),
                const SizedBox(height: 28),

                // Öne çıkanlar
                _feature(isDark, Icons.verified_user_rounded,
                    'Belgeyle doğrulanmış roller',
                    'Antrenör kademeleri ve sporcu lisansları platformca onaylanır.'),
                _feature(isDark, Icons.groups_rounded, 'Kadro & yoklama',
                    'Sporcuları yönet, tek dokunuşla yoklama al.'),
                _feature(isDark, Icons.calendar_month_rounded,
                    'Antrenman & maç takvimi',
                    'Program herkese anında ulaşsın.'),
                _feature(isDark, Icons.family_restroom_rounded, 'Veli erişimi',
                    'Veliler davet koduyla çocuklarına bağlanır.'),
                _feature(isDark, Icons.payments_rounded, 'Aidat & sağlık',
                    'Ödemeleri ve sakatlıkları tek yerden izle.'),

                const SizedBox(height: 30),

                // CTA
                if (signedIn) ...[
                  _primaryButton(
                    label: 'Panele Git',
                    icon: Icons.arrow_forward_rounded,
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/dashboard', (_) => false),
                  ),
                ] else ...[
                  _primaryButton(
                    label: 'Giriş Yap',
                    icon: Icons.login_rounded,
                    onTap: () {
                      final ctrl = ref.read(authControllerProvider.notifier);
                      if (ref.read(authControllerProvider).mode !=
                          AuthMode.signIn) {
                        ctrl.toggleMode();
                      }
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (_) => false);
                    },
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      final ctrl = ref.read(authControllerProvider.notifier);
                      if (ref.read(authControllerProvider).mode !=
                          AuthMode.signUp) {
                        ctrl.toggleMode();
                      }
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (_) => false);
                    },
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_alt_rounded,
                              size: 18, color: kTeal),
                          const SizedBox(width: 8),
                          Text('Hesap Oluştur',
                              style: jakarta(14.5, FontWeight.w800, ink)),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                Center(
                  child: Text('Kulüpler, antrenörler, sporcular ve veliler için',
                      textAlign: TextAlign.center,
                      style: jakarta(
                          11.5, FontWeight.w500, SwanColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kTealBright, kTeal]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kTeal.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: jakarta(15, FontWeight.w800, Colors.white)),
            const SizedBox(width: 8),
            Icon(icon, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _feature(bool isDark, IconData icon, String title, String sub) {
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: jakarta(13.5, FontWeight.w800, ink)),
                const SizedBox(height: 2),
                Text(sub,
                    style: jakarta(
                        11.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

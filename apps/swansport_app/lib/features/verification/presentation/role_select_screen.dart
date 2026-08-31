import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Rol Seçimi — kayıt sonrası kullanıcı yolunu seçer (premium v3).
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [kTealBright, kTealDeep]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: kTeal.withValues(alpha: .34),
                          blurRadius: 18,
                          offset: const Offset(0, 8),),
                    ],
                  ),
                  alignment: Alignment.center,
                  child:
                      Text('S', style: SwanType.h2(Colors.white)),
                ),
                const SizedBox(height: 22),
                Text('Nasıl devam\netmek istersin?',
                    style: SwanType.h1(ink),),
                const SizedBox(height: 8),
                Text('Rolünü seç — doğrulama adımların buna göre belirlenir.',
                    style: SwanType.bodySm(SwanColors.textSecondary),),
                const SizedBox(height: 24),
                _card(context, isDark,
                    icon: Icons.person_rounded,
                    bg: const Color(0xFFE2F4F3),
                    fg: kTeal,
                    title: 'Sporcuyum',
                    sub: 'Lisanslı veya ferdi sporcu',
                    route: '/dogrulama',),
                _card(context, isDark,
                    icon: Icons.sports_rounded,
                    bg: const Color(0xFFFBF0DC),
                    fg: const Color(0xFFB5730A),
                    title: 'Antrenörüm',
                    sub: '1–5. kademe belgeni doğrulat',
                    route: '/dogrulama',),
                _card(context, isDark,
                    icon: Icons.campaign_rounded,
                    bg: const Color(0xFFE5EEFE),
                    fg: const Color(0xFF2563EB),
                    title: 'Veliyim',
                    sub: 'Çocuğunu davet kodu ile bağla',
                    route: '/veli-bagla',),
                _card(context, isDark,
                    icon: Icons.account_balance_rounded,
                    bg: kTeal,
                    fg: Colors.white,
                    title: 'Kulüp kurmak istiyorum',
                    sub: '≥2. kademe + resmi evrak gerekir',
                    route: '/athletes',
                    highlight: true,),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, bool isDark,
      {required IconData icon,
      required Color bg,
      required Color fg,
      required String title,
      required String sub,
      required String route,
      bool highlight = false,}) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: highlight ? kTeal.withValues(alpha: .5) : line),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .25 : .05),
                blurRadius: 14,
                offset: const Offset(0, 5),),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(13),),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  Text(sub,
                      style: SwanType.caption(SwanColors.textSecondary),),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: SwanColors.textSecondary, size: 20,),
          ],
        ),
      ),
    );
  }
}

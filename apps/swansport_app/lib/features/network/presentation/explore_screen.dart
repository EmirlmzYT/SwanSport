import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Keşfet — uygulamanın ikinci ana merkezi.
///
/// **34 girişlik modül menüsünün yerini alan iki ekrandan biri** (öteki
/// Profil > Yönetim). Menü kalktı ama hiçbir rota silinmedi; buradan
/// gidiliyor.
///
/// Brief §7'nin uyarısı tasarımı belirledi: *"Keşfet ekranı bir admin menüsü
/// gibi görünmemeli."* Bu yüzden küçük ikonlu ızgara değil — her satır
/// başlığı, açıklaması ve nefes alanı olan bir liste. İkon ızgarası tam da
/// kaçtığımız "katalog" hissini geri getirirdi.
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 132),
              children: [
                Text('Keşfet', style: SwanType.h1(c.ink)),
                const SizedBox(height: SwanSpace.lg),
                _SearchField(c: c),
                const SizedBox(height: SwanSpace.xl),

                _section(c, 'Spor yap'),
                _Row(
                  c: c,
                  icon: Icons.stadium_rounded,
                  title: 'Sahalar',
                  subtitle: 'Halka açık kortlar ve halı sahalar',
                  route: '/kortlar',
                ),
                _Row(
                  c: c,
                  icon: Icons.handshake_rounded,
                  title: 'Partner bul',
                  subtitle: 'Birlikte oynayacak birini ara',
                  route: '/partner-ara',
                ),
                _Row(
                  c: c,
                  icon: Icons.campaign_rounded,
                  title: 'İlanlar',
                  subtitle: 'Malzeme al, sat ya da ara',
                  route: '/ilanlar',
                ),

                const SizedBox(height: SwanSpace.xl),
                _section(c, 'İnsanlar ve kulüpler'),
                _Row(
                  c: c,
                  icon: Icons.travel_explore_rounded,
                  title: 'Kulüpler',
                  subtitle: 'İl, ilçe ve branşa göre bul',
                  route: '/kulupler',
                ),
                _Row(
                  c: c,
                  icon: Icons.forum_rounded,
                  title: 'Topluluklar',
                  subtitle: 'İlinin antrenör grupları',
                  route: '/topluluklar',
                ),
                _Row(
                  c: c,
                  icon: Icons.emoji_events_rounded,
                  title: 'Organizasyonlar',
                  subtitle: 'Turnuva, kamp ve etkinlikler',
                  route: '/organizasyonlar',
                ),
                if (access.isClubStaff)
                  _Row(
                    c: c,
                    icon: Icons.shield_rounded,
                    title: 'Takımlar',
                    subtitle: 'Kadrolar ve takım sayfaları',
                    route: '/teams',
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _section(SwanPalette c, String title) => Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.sm),
        child: Text(title, style: SwanType.h3(c.ink)),
      );
}

/// "Ne arıyorsun?" — dokununca arama ekranını açar.
///
/// Gerçek `TextField` değil: arama ayrı bir ekran ve orada odaklanmış bir
/// alan var. Burada iki tane arama kutusu olması kafa karıştırırdı.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.c});
  final SwanPalette c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushNamed(context, '/ara'),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Row(children: [
          Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
          const SizedBox(width: SwanSpace.md),
          Text('Ne arıyorsun?', style: SwanType.body(c.inkMuted)),
        ]),
      ),
    );
  }
}

/// Keşif satırı.
///
/// Kart değil: zemin farkı ve boşlukla ayrılıyor. Brief §19 —
/// *"Card yerine mümkün olduğunca section / list kullan."*
class _Row extends StatelessWidget {
  const _Row({
    required this.c,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final SwanPalette c;
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushNamed(context, route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Icon(icon, color: c.accent, size: 21),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SwanType.body(c.ink, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.inkMuted),
        ]),
      ),
    );
  }
}

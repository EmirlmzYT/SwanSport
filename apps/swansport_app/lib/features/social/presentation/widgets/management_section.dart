import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

/// Profil > Yönetim — modül menüsünün ikinci yarısının evi.
///
/// **34 girişlik menü kalktı**; keşif modülleri Keşfet'e, kişisel ve yönetim
/// modülleri buraya geldi. Hiçbir rota silinmedi, yalnızca giriş noktaları
/// değişti.
///
/// Brief §13: *"Yöneticiye 15 adet menü seçeneğini aynı anda gösterme,
/// 'Yönetim' altında kategorize et."* Bu yüzden bölümler var ve her bölüm
/// yalnızca kişinin gerçekten erişebildiği satırları gösteriyor — erişilemeyen
/// bir satırı sönük göstermek yerine hiç göstermiyoruz.
///
/// Yalnızca kendi profilinde ve yalnızca ilgili rolde görünür.
class ManagementSection extends ConsumerWidget {
  const ManagementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);

    final club = <_Item>[
      if (access.isClubStaff) ...[
        const _Item(Icons.groups_rounded, 'Sporcular', '/athletes'),
        const _Item(Icons.shield_rounded, 'Takımlar', '/teams'),
        const _Item(Icons.calendar_month_rounded, 'Takvim', '/calendar'),
        const _Item(Icons.checklist_rounded, 'Yoklama Al', '/attendance'),
        const _Item(Icons.fact_check_rounded, 'Devam Geçmişi', '/devam-durumu'),
        const _Item(Icons.campaign_rounded, 'Duyurular', '/announcements'),
        const _Item(Icons.bar_chart_rounded, 'Performans',
            '/performance-analytics'),
        const _Item(Icons.dashboard_rounded, 'Komuta Merkezi', '/home-command'),
      ],
    ];

    final ops = <_Item>[
      if (access.isClubStaff || access.isAccountant) ...[
        const _Item(Icons.payments_rounded, 'Aidat Yönetimi', '/finans'),
        const _Item(Icons.receipt_long_rounded, 'Gider Ekle', '/gider-ekle'),
        const _Item(Icons.description_rounded, 'Raporlar', '/reports'),
      ],
      if (access.isClubStaff) ...[
        const _Item(Icons.medical_services_rounded, 'Medikal',
            '/medical-center'),
        const _Item(Icons.stadium_rounded, 'Tesisler', '/facilities'),
      ],
    ];

    final platform = <_Item>[
      if (access.isPlatformAdmin) ...[
        const _Item(Icons.admin_panel_settings_rounded, 'Onay Paneli',
            '/onay-paneli'),
        const _Item(Icons.rss_feed_rounded, 'Haber Kaynakları',
            '/haber-kaynaklari'),
        const _Item(Icons.verified_rounded, 'Federasyon Yetkilileri',
            '/federasyon-yetkili'),
        const _Item(Icons.tune_rounded, 'Yapılandırma', '/configuration'),
      ],
    ];

    final account = <_Item>[
      const _Item(Icons.volunteer_activism_rounded, 'Bağış', '/bagis'),
      const _Item(Icons.group_add_rounded, 'Başvurular', '/basvurular'),
      const _Item(Icons.vpn_key_rounded, 'Davet Kodu', '/veli-bagla'),
      const _Item(Icons.settings_rounded, 'Ayarlar', '/settings'),
    ];

    final groups = <(String, List<_Item>)>[
      if (club.isNotEmpty) ('Kulübüm', club),
      if (ops.isNotEmpty) ('Kulüp işleri', ops),
      if (platform.isNotEmpty) ('Platform', platform),
      ('Hesabım', account),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups) ...[
          const SizedBox(height: SwanSpace.xl),
          Text(g.$1, style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          for (final item in g.$2) _row(context, c, item),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, SwanPalette c, _Item item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pushNamed(context, item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        child: Row(children: [
          Icon(item.icon, size: 20, color: c.inkMuted),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Text(item.label, style: SwanType.body(c.ink)),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.inkMuted),
        ]),
      ),
    );
  }
}

class _Item {
  const _Item(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

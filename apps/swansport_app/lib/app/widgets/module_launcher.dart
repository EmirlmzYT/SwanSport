import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../features/demo/demo_role.dart';
import 'premium.dart';
import 'recent_modules.dart';

/// Modül kataloğu ve alttan açılan başlatıcı menü.
///
/// `premium.dart` içinden ayrıldı: orada tasarım bileşenleri (avatar, rozet,
/// alt bar, tipografi) duruyor; burada uygulamanın modül haritası. İkisi farklı
/// sebeplerle değişiyor — modül eklemek tasarımı, renk değiştirmek modül
/// listesini ilgilendirmiyor.
///
/// `premium.dart` bu dosyayı yeniden dışa aktarır; mevcut importlar çalışmaya
/// devam eder.

/// Tüm modüllere erişim için alttan açılan başlatıcı menü.
/// Ortadaki menü butonundan her ekrandan çağrılır.
const List<(IconData, String, String, int)> kAllModules = [
  (Icons.dynamic_feed_rounded, 'Akış', '/akis', 0xFF008C95),
  (Icons.search_rounded, 'Ara', '/ara', 0xFF0EA5E9),
  (Icons.travel_explore_rounded, 'Kulüpleri Keşfet', '/kesfet',
      0xFF008C95),
  (Icons.campaign_rounded, 'İlanlar', '/ilanlar', 0xFFFF7A59),
  (Icons.sports_tennis_rounded, 'Kortlar', '/kortlar', 0xFF3FB950),
  (Icons.group_add_rounded, 'Oyuncu Aranıyor', '/oyuncu-aranan', 0xFFD9860B),
  (Icons.handshake_rounded, 'Partner Ara', '/partner-ara', 0xFF8B5CF6),
  (Icons.grass_rounded, 'Halı Sahalar', '/halisahalar', 0xFF3FB950),
  (Icons.emoji_events_rounded, 'Organizasyonlar',
      '/organizasyonlar', 0xFFE9B949),
  (Icons.notifications_rounded, 'Bildirimler', '/bildirimler', 0xFFF43F5E),
  (Icons.chat_bubble_rounded, 'Mesajlar', '/mesajlar', 0xFF7C5CE6),
  (Icons.forum_rounded, 'Topluluklar', '/topluluklar', 0xFF008C95),
  (Icons.rss_feed_rounded, 'Haber Kaynakları', '/haber-kaynaklari', 0xFFFF7A59),
  (Icons.verified_rounded, 'Federasyon Yetkilileri', '/federasyon-yetkili',
      0xFF008C95),
  (Icons.group_add_rounded, 'Başvurular', '/basvurular', 0xFF10B981),
  (Icons.person_rounded, 'Profilim', '/profil', 0xFF7C5CE6),
  (Icons.home_rounded, 'Antrenör Paneli', '/dashboard', 0xFF008C95),
  (Icons.dashboard_rounded, 'Komuta Merkezi', '/home-command', 0xFF0EA5E9),
  (Icons.groups_rounded, 'Sporcular', '/athletes', 0xFF008C95),
  (Icons.calendar_month_rounded, 'Takvim', '/calendar', 0xFF3B82F6),
  (Icons.checklist_rounded, 'Yoklama Al', '/attendance', 0xFF10B981),
  (Icons.fact_check_rounded, 'Devam Geçmişi', '/devam-durumu', 0xFF10B981),
  (Icons.campaign_rounded, 'Duyurular', '/announcements', 0xFFFF7A59),
  (Icons.bar_chart_rounded, 'Performans', '/performance-analytics', 0xFF7C5CE6),
  (Icons.payments_rounded, 'Aidat Yönetimi', '/finans', 0xFFE9B949),
  (Icons.receipt_long_rounded, 'Gider Ekle', '/gider-ekle', 0xFFC2410C),
  (Icons.receipt_long_rounded, 'Aidatlarım', '/aidatlarim', 0xFF10B981),
  (Icons.volunteer_activism_rounded, 'Bağış', '/bagis', 0xFFFF7A59),
  (Icons.medical_services_rounded, 'Medikal', '/medical-center', 0xFFEF4444),
  (Icons.description_rounded, 'Raporlar', '/reports', 0xFF0EA5E9),
  (Icons.folder_rounded, 'Belgeler', '/documents', 0xFFF59E0B),
  (Icons.stadium_rounded, 'Tesisler', '/facilities', 0xFF14B8A6),
  (Icons.shield_rounded, 'Takımlar', '/teams', 0xFF6366F1),
  (Icons.tune_rounded, 'Yapılandırma', '/configuration', 0xFF7C5CE6),
  (Icons.settings_rounded, 'Ayarlar', '/settings', 0xFF64748B),
  (Icons.shield_outlined, 'Gizlilik', '/gizlilik', 0xFF64748B),
  (Icons.verified_user_rounded, 'Doğrulama', '/dogrulama', 0xFF10B981),
  (Icons.vpn_key_rounded, 'Davet Kodu', '/veli-bagla', 0xFF3B82F6),
  (
    Icons.admin_panel_settings_rounded,
    'Onay Paneli',
    '/onay-paneli',
    0xFFF43F5E
  ),
];

/// Modüller anlamlı öbeklere ayrılır: 27 simgeyi tek yığın halinde göstermek
/// yerine kullanıcının aradığı şeyi öbek başlığından bulmasını sağlar.
/// Burada adı geçmeyen rota "Diğer" öbeğine düşer.
const Map<String, String> kModuleGroup = {
  // Spor yapmanın kendisi: nerede, kiminle, hangi malzemeyle.
  // Bu beşi tek bir kullanıcı yolculuğu — akış/mesaj kalabalığının arasına
  // dağıtıldıklarında hiçbiri bulunamıyordu.
  '/kortlar': 'Spor Yap',
  '/halisahalar': 'Spor Yap',
  '/partner-ara': 'Spor Yap',
  '/oyuncu-aranan': 'Spor Yap',
  '/ilanlar': 'Spor Yap',

  '/akis': 'Sosyal',
  '/ara': 'Sosyal',
  '/kesfet': 'Sosyal',
  '/topluluklar': 'Sosyal',
  '/organizasyonlar': 'Sosyal',
  '/mesajlar': 'Sosyal',
  '/bildirimler': 'Sosyal',

  '/dashboard': 'Kulübüm',
  '/home-command': 'Kulübüm',
  '/athletes': 'Kulübüm',
  '/teams': 'Kulübüm',
  '/calendar': 'Kulübüm',
  '/attendance': 'Kulübüm',
  '/devam-durumu': 'Kulübüm',
  '/announcements': 'Kulübüm',
  '/performance-analytics': 'Kulübüm',

  '/finans': 'Kulüp İşleri',
  '/gider-ekle': 'Kulüp İşleri',
  '/medical-center': 'Kulüp İşleri',
  '/reports': 'Kulüp İşleri',
  '/documents': 'Kulüp İşleri',
  '/facilities': 'Kulüp İşleri',

  // Kendi hesabına, kendi parana, kendi belgene dair olanlar.
  // `/aidatlarim` burada, `/finans` (kulübün aidat yönetimi) yukarıda —
  // adları benziyor ama biri senin borcun, öbürü kulübün defteri.
  '/profil': 'Hesabım',
  '/aidatlarim': 'Hesabım',
  '/bagis': 'Hesabım',
  '/dogrulama': 'Hesabım',
  '/veli-bagla': 'Hesabım',
  '/basvurular': 'Hesabım',
  '/gizlilik': 'Hesabım',
  '/settings': 'Hesabım',

  '/onay-paneli': 'Yönetim',
  '/haber-kaynaklari': 'Yönetim',
  '/federasyon-yetkili': 'Yönetim',
  '/configuration': 'Yönetim',
};

const List<String> kModuleGroupOrder = [
  'Spor Yap',
  'Sosyal',
  'Kulübüm',
  'Kulüp İşleri',
  'Hesabım',
  'Yönetim',
  'Diğer',
];

/// Verilen modülleri öbeklere ayırır; boş öbekler düşer.
List<(String, List<(IconData, String, String, int)>)> groupModules(
    List<(IconData, String, String, int)> modules) {
  final byGroup = <String, List<(IconData, String, String, int)>>{};
  for (final m in modules) {
    byGroup.putIfAbsent(kModuleGroup[m.$3] ?? 'Diğer', () => []).add(m);
  }
  return [
    for (final g in kModuleGroupOrder)
      if (byGroup[g] != null) (g, byGroup[g]!),
  ];
}

/// Öbek başlığı — sessiz, büyük harf, ince.
Widget moduleGroupLabel(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title.toUpperCase(),
          style: jakarta(10.5, FontWeight.w800, SwanColors.textSecondary,
              ls: 1.3)),
    );

void showModuleLauncher(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
  final ink = isDark ? Colors.white : SwanColors.textPrimary;
  final grip = isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0);

  // Demo rol katmanını oku (WidgetRef yok — container üzerinden).
  final container = ProviderScope.containerOf(context, listen: false);
  final allowed = container.read(effectiveAllowedRoutesProvider);
  final demoLabel = container.read(effectiveRoleLabelProvider);
  // Demo şeridi yalnızca geliştirme derlemesinde görünür.
  final showDemoTools = container.read(debugToolsEnabledProvider);
  final modules =
      kAllModules.where((m) => demoAllows(allowed, m.$3)).toList();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.of(sheetContext).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: grip,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text('Modüller', style: sora(19, FontWeight.w800, ink)),
            const SizedBox(height: 12),
            const _ClubSwitcherRow(),
            const SizedBox(height: 6),

            Flexible(
              child: _LauncherBody(
                modules: modules,
                onOpen: (route) {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed(route);
                },
              ),
            ),

            // Demo şeridi en altta, sessiz bir satır olarak — yalnızca
            // geliştirme derlemesinde.
            if (showDemoTools) ...[
            Divider(color: grip, height: 1),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed('/demo-rol');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  Icon(Icons.theater_comedy_outlined,
                      size: 17,
                      color:
                          demoLabel == null ? SwanColors.textSecondary : kTeal),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      demoLabel == null
                          ? 'Demo rollerini dene'
                          : 'Demo: $demoLabel',
                      style: jakarta(12, FontWeight.w700,
                          demoLabel == null ? SwanColors.textSecondary : kTeal),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: SwanColors.textSecondary),
                ]),
              ),
            ),
            ],
          ],
        ),
      );
    },
  );
}

/// Tek renkli modül karesi. Simge rengi modülü ayırt etmiyordu — ad ayırt
/// ediyor; renk yalnızca gürültü ekliyordu, o yüzden nötr tutuldu.
class ModuleTile extends StatelessWidget {
  const ModuleTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final fill = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: ink.withValues(alpha: 0.82), size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: jakarta(10, FontWeight.w600, ink),
          ),
        ],
      ),
    );
  }
}

/// Birden fazla kulüpte görevli olanlar için kulüp seçici.
///
/// Modül menüsünde duruyor çünkü kulüp değiştirmek bir modül seçmekle aynı
/// nitelikte: bundan sonra açacağın her ekranın bağlamını belirliyor.
///
/// Tek kulübü olana hiç görünmez — seçenek yokken seçim arayüzü göstermek
/// kullanıcıya olmayan bir karar sunmak olurdu.
class _ClubSwitcherRow extends ConsumerWidget {
  const _ClubSwitcherRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(myClubsProvider).valueOrNull ?? const <ClubRef>[];
    if (clubs.length < 2) return const SizedBox.shrink();

    final active = ref.watch(activeClubProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in clubs)
            GestureDetector(
              onTap: () =>
                  ref.read(selectedClubIdProvider.notifier).state = c.id,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: c.id == active?.id
                      ? kTeal.withValues(alpha: .12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: c.id == active?.id
                        ? kTeal.withValues(alpha: .45)
                        : SwanColors.outline.withValues(alpha: .5),
                  ),
                ),
                child: Text(
                  c.name,
                  style: jakarta(
                    12,
                    c.id == active?.id ? FontWeight.w700 : FontWeight.w500,
                    c.id == active?.id ? kTeal : ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Türkçe duyarsız arama için harf katlama.
///
/// `'İlanlar'.toLowerCase()` Dart'ta birleşik noktalı bir `i` üretiyor ve
/// kullanıcının yazdığı düz `ilan` ile eşleşmiyor — Türkçe'de bu klasik
/// tuzak. Burada İ/I/ı hepsi düz `i`'ye katlanıyor, böylece "halı" arayan da
/// "hali" arayan da Halı Sahalar'ı buluyor.
String foldTr(String input) {
  const map = {
    'İ': 'i', 'I': 'i', 'ı': 'i',
    'Ş': 's', 'ş': 's',
    'Ğ': 'g', 'ğ': 'g',
    'Ü': 'u', 'ü': 'u',
    'Ö': 'o', 'ö': 'o',
    'Ç': 'c', 'ç': 'c',
  };
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    buf.write(map[ch] ?? ch.toLowerCase());
  }
  return buf.toString();
}

/// Modülleri arama metnine göre süzer. Boş sorgu hepsini döndürür.
List<(IconData, String, String, int)> filterModules(
  List<(IconData, String, String, int)> modules,
  String query,
) {
  final q = foldTr(query.trim());
  if (q.isEmpty) return modules;
  return modules.where((m) => foldTr(m.$2).contains(q)).toList();
}

/// Menünün gövdesi: arama + son kullanılanlar + öbeklenmiş ızgara.
///
/// Ayrı bir widget çünkü arama metni durum tutuyor; `showModuleLauncher`
/// bir fonksiyon ve durum tutamaz.
class _LauncherBody extends StatefulWidget {
  const _LauncherBody({required this.modules, required this.onOpen});

  final List<(IconData, String, String, int)> modules;
  final void Function(String route) onOpen;

  @override
  State<_LauncherBody> createState() => _LauncherBodyState();
}

class _LauncherBodyState extends State<_LauncherBody> {
  final _search = TextEditingController();
  String _query = '';
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    recentRoutes().then((r) {
      if (mounted) setState(() => _recent = r);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(String route) {
    // Sırayı kaydet, ama açılışı bekletme — kayıt başarısız olsa bile
    // kullanıcı ekrana gitmeli.
    pushRecent(route);
    widget.onOpen(route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final field = isDark ? const Color(0xFF1A2537) : const Color(0xFFF4F7FA);

    final filtered = filterModules(widget.modules, _query);
    final searching = _query.trim().isNotEmpty;

    // Son kullanılanlar yalnızca kullanıcının hâlâ erişebildiği modüller —
    // rolü değişmişse eski kısayol ölü bağlantı olmamalı.
    final byRoute = {for (final m in widget.modules) m.$3: m};
    final recentModules = [
      for (final r in _recent)
        if (byRoute[r] != null) byRoute[r]!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          style: jakarta(13.5, FontWeight.w600, ink),
          decoration: InputDecoration(
            hintText: 'Modül ara',
            hintStyle:
                jakarta(13.5, FontWeight.w600, SwanColors.textSecondary),
            prefixIcon:
                const Icon(Icons.search_rounded, size: 19, color: kTeal),
            suffixIcon: searching
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: field,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (searching) ...[
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text('Eşleşen modül yok',
                            style: jakarta(13, FontWeight.w600,
                                SwanColors.textSecondary)),
                      ),
                    )
                  else
                    // Aramada öbek başlıkları gösterilmiyor: sonuç zaten
                    // az, başlıklar gürültü olurdu.
                    _grid(filtered),
                ] else ...[
                  if (recentModules.isNotEmpty) ...[
                    moduleGroupLabel('Son kullandıkların'),
                    _grid(recentModules),
                    const SizedBox(height: 20),
                  ],
                  for (final g in groupModules(widget.modules)) ...[
                    moduleGroupLabel(g.$1),
                    _grid(g.$2),
                    const SizedBox(height: 20),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _grid(List<(IconData, String, String, int)> items) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.86,
        children: [
          for (final m in items)
            ModuleTile(
              icon: m.$1,
              label: m.$2,
              onTap: () => _open(m.$3),
            ),
        ],
      );
}

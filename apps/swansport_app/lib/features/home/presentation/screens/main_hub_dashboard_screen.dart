import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class MainHubDashboardScreen extends ConsumerWidget {
  const MainHubDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwanColors.darkBackground : SwanColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('SwanSport — Ana Hub Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.public),
            tooltip: 'Tanıtım Sayfası',
            onPressed: () => Navigator.pushNamed(context, '/landing'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final isDesktop = box.maxWidth >= 900;

          final kpiHeader = Container(
            key: const Key('hub-hero-kpis'),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF008C95),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KULÜP KONTROL MERKEZİ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kadıköy SK • Canlı Durum Özeti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _kpiChip('420', 'Aktif Sporcu'),
                    _kpiChip('%94', 'Bugün Katılım'),
                    _kpiChip('%98', 'Tıbbi Uyum'),
                    _kpiChip('%88', 'Aidat Tahsilat'),
                    _kpiChip('%92', 'Takım Hazır Olma'),
                  ],
                ),
              ],
            ),
          );

          final launcherGrid = Column(
            key: const Key('hub-launcher-section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '15 ENTERPRISE MODÜL BAŞLATICI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                  color: SwanColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tüm Modüllere Tek Tıkla Erişim',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 3 : (box.maxWidth < 600 ? 1 : 2),
                childAspectRatio:
                    isDesktop ? 2.2 : (box.maxWidth < 600 ? 3.0 : 2.0),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: const [
                  _HubLauncherItem(
                    key: Key('launch-athletes'),
                    icon: Icons.sports_soccer,
                    title: 'Sporcu Yönetimi',
                    subtitle: 'Screen 3 • Sporcu Profil',
                    route: '/athletes',
                    color: Colors.teal,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-attendance'),
                    icon: Icons.fact_check,
                    title: 'Yoklama & Katılım',
                    subtitle: 'Screen 4 • Canlı Yoklama',
                    route: '/attendance',
                    color: Colors.blue,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-calendar'),
                    icon: Icons.calendar_month,
                    title: 'Takvim & Program',
                    subtitle: 'Screen 6 • Etkinlikler',
                    route: '/calendar',
                    color: Colors.purple,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-announcements'),
                    icon: Icons.campaign,
                    title: 'İletişim & Duyuru',
                    subtitle: 'Screen 7 • Bildirimler',
                    route: '/announcements',
                    color: Colors.orange,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-teams'),
                    icon: Icons.groups,
                    title: 'Takımlar & Şubeler',
                    subtitle: 'Screen 5 • Kadro Yönetimi',
                    route: '/teams',
                    color: Colors.indigo,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-documents'),
                    icon: Icons.folder,
                    title: 'Evrak & Belgeler',
                    subtitle: 'Screen 8 • Lisans & Muvafakat',
                    route: '/documents',
                    color: Colors.brown,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-settings'),
                    icon: Icons.settings,
                    title: 'Kulüp Ayarları',
                    subtitle: 'Screen 9 • Şube Yetkileri',
                    route: '/settings',
                    color: Colors.blueGrey,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-configuration'),
                    icon: Icons.tune,
                    title: 'Konfigürasyon',
                    subtitle: 'Screen 10 • Parametreler',
                    route: '/configuration',
                    color: Colors.cyan,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-facilities'),
                    icon: Icons.stadium,
                    title: 'Tesis Yönetimi',
                    subtitle: 'Screen 11 • Saha Doluluk',
                    route: '/facilities',
                    color: Colors.green,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-medical-center'),
                    icon: Icons.medical_services,
                    title: 'Medikal Merkez',
                    subtitle: 'Screen 12 • Sağlık & Sakatlık',
                    route: '/medical-center',
                    color: Colors.redAccent,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-reports'),
                    icon: Icons.analytics,
                    title: 'Raporlama & BI',
                    subtitle: 'Screen 13 • İş Zekası',
                    route: '/reports',
                    color: Colors.deepPurple,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-financial-management'),
                    icon: Icons.account_balance_wallet,
                    title: 'Finans Yönetimi',
                    subtitle: 'Screen 14 • Aidat & Muhasebe',
                    route: '/financial-management',
                    color: Colors.amber,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-performance-analytics'),
                    icon: Icons.insights,
                    title: 'Performans Analizi',
                    subtitle: 'Screen 15 • Test & Gelişim',
                    route: '/performance-analytics',
                    color: Colors.teal,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-dashboard'),
                    icon: Icons.dashboard,
                    title: 'Koç Paneli',
                    subtitle: 'Screen 2 • Günlük Özet',
                    route: '/dashboard',
                    color: Colors.lightBlue,
                  ),
                  _HubLauncherItem(
                    key: Key('launch-auth'),
                    icon: Icons.lock,
                    title: 'Kimlik Doğrulama',
                    subtitle: 'Screen 1 • Giriş Ekranı',
                    route: '/',
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          );

          if (isDesktop) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                kpiHeader,
                const SizedBox(height: 24),
                launcherGrid,
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              kpiHeader,
              const SizedBox(height: 20),
              launcherGrid,
            ],
          );
        },
      ),
    );
  }

  Widget _kpiChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _HubLauncherItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;

  const _HubLauncherItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

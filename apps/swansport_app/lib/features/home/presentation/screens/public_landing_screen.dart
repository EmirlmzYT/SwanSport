import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class PublicLandingScreen extends StatelessWidget {
  const PublicLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PublicLandingContent();
  }
}

class _PublicLandingContent extends StatelessWidget {
  const _PublicLandingContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwanColors.darkBackground : SwanColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SwanColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.sports_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SwanSport',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.login_rounded),
            tooltip: 'Giriş Yap',
            onPressed: () => Navigator.pushNamed(context, '/'),
          ),
          IconButton(
            key: const Key('landing-to-hub-btn'),
            icon:
                const Icon(Icons.dashboard_rounded, color: SwanColors.primary),
            tooltip: 'Ana Hub Dashboard',
            onPressed: () => Navigator.pushNamed(context, '/hub'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          // Hero Section
          Container(
            key: const Key('landing-hero'),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF008C95),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF008C95).withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ENTERPRISE SPORTS MANAGEMENT PLATFORM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Spor Kulüpleri & Akademiler İçin\nGeleceğin Dijital Yönetim Platformu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SwanSport; sporcu takibinden medikal merkeze, finans yönetiminden performans analitiğine kadar 15 entegre enterprise modül ile kulübünüzü tek merkezden yönetmenizi sağlar.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      key: const Key('hero-launch-hub-btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF008C95),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/hub'),
                      icon: const Icon(Icons.dashboard_rounded),
                      label: const Text(
                        'Ana Hub Dashboard\'u Başlat',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/'),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Kulüp Girişi'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // 15 Enterprise Modules Section
          const Text(
            'ENTERPRISE MODÜL EKOSİSTEMİ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: SwanColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '15 Entegre İşletim Modülü',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),

          GridView.count(
            key: const Key('landing-modules-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width >= 840 ? 3 : 1,
            childAspectRatio: 2.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: const [
              _ModuleCard(
                icon: Icons.sports_soccer,
                title: 'Sporcu Yönetimi (Screen 3)',
                desc:
                    'Sporcu kimlikleri, lisanslar, veli eşleşmesi ve kadro takibi.',
                route: '/athletes',
              ),
              _ModuleCard(
                icon: Icons.fact_check,
                title: 'Yoklama & Katılım (Screen 4)',
                desc: 'Canlı sahadan yoklama alma ve devamsızlık uyarıları.',
                route: '/attendance',
              ),
              _ModuleCard(
                icon: Icons.calendar_month,
                title: 'Takvim & Program (Screen 6)',
                desc: 'Antrenman, maç ve etkinlik takvim yönetimi.',
                route: '/calendar',
              ),
              _ModuleCard(
                icon: Icons.campaign,
                title: 'İletişim & Duyuru (Screen 7)',
                desc: 'Veli ve sporculara anlık duyuru ve onay takibi.',
                route: '/announcements',
              ),
              _ModuleCard(
                icon: Icons.groups,
                title: 'Takımlar & Şubeler (Screen 5/9)',
                desc: 'Şube bazlı takım ve antrenör kadro yapılandırması.',
                route: '/teams',
              ),
              _ModuleCard(
                icon: Icons.folder,
                title: 'Evrak & Belgeler (Screen 8)',
                desc: 'Sözleşme, muvafakatname ve lisans belgeleri.',
                route: '/documents',
              ),
              _ModuleCard(
                icon: Icons.settings,
                title: 'Kulüp Ayarları (Screen 9)',
                desc: 'Şube yetkileri, rol tanımları ve kulüp politikaları.',
                route: '/settings',
              ),
              _ModuleCard(
                icon: Icons.tune,
                title: 'Konfigürasyon (Screen 10)',
                desc: 'Sistem parametreleri ve dinamik alan ayarları.',
                route: '/configuration',
              ),
              _ModuleCard(
                icon: Icons.stadium,
                title: 'Tesis Yönetimi (Screen 11)',
                desc: 'Saha, salon doluluk oranları ve bakım takibi.',
                route: '/facilities',
              ),
              _ModuleCard(
                icon: Icons.medical_services,
                title: 'Medikal Merkez (Screen 12)',
                desc: 'Sağlık raporları, sakatlık takibi ve uygunluk.',
                route: '/medical-center',
              ),
              _ModuleCard(
                icon: Icons.analytics,
                title: 'Raporlama & BI (Screen 13)',
                desc: 'Yönetsel karar destek ve iş zekası raporları.',
                route: '/reports',
              ),
              _ModuleCard(
                icon: Icons.account_balance_wallet,
                title: 'Finans Yönetimi (Screen 14)',
                desc: 'Aidat takibi, faturalar, giderler ve bütçe.',
                route: '/financial-management',
              ),
              _ModuleCard(
                icon: Icons.insights,
                title: 'Performans Analizi (Screen 15)',
                desc: 'Fiziksel testler, teknik/taktik skoring ve IDP.',
                route: '/performance-analytics',
              ),
              _ModuleCard(
                icon: Icons.dashboard,
                title: 'Koç Paneli (Screen 2)',
                desc: 'Antrenör komuta merkezi ve günlük özetler.',
                route: '/dashboard',
              ),
              _ModuleCard(
                icon: Icons.lock,
                title: 'Giriş & Güvenlik (Screen 1)',
                desc: 'Güvenli giriş, biyometrik doğrulama ve oturum.',
                route: '/',
              ),
            ],
          ),

          const SizedBox(height: 48),

          Wrap(
            key: const Key('landing-commercial-placeholders'),
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 320,
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: const Text('Kurumsal Fiyatlandırma'),
                    subtitle: const Text(
                      'Fiyatlandırma entegrasyonu henüz bağlı değil.',
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fiyatlandırma yakında paylaşılacak.'),
                        ),
                      ),
                      child: const Text('Bilgi Al'),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.contact_support_outlined),
                    title: const Text('Kurumsal İletişim'),
                    subtitle: const Text(
                      'İletişim altyapısı için güvenli yönlendirme yer tutucusu.',
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('İletişim kanalı yakında açılacak.'),
                        ),
                      ),
                      child: const Text('İletişim'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              '© 2026 SwanSport Enterprise Sports Platform • Tüm Hakları Saklıdır',
              style: TextStyle(
                color: isDark ? Colors.white54 : SwanColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final String route;

  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SwanColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: SwanColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? Colors.white70 : SwanColors.textSecondary,
                      ),
                      maxLines: 2,
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

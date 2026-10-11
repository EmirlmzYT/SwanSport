import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

const kSetupWizardSeenKey = 'setup_wizard_seen_v1';

/// Kurulum rehberinin görülüp görülmediği.
Future<bool> setupWizardSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kSetupWizardSeenKey) ?? false;
  } catch (_) {
    return true;
  }
}

/// Kurulum rehberini görüldü olarak işaretle.
Future<void> markSetupWizardSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kSetupWizardSeenKey, true);
  } catch (_) {
    // Yazılamasa da akış devam eder.
  }
}

/// Yeni kayıt olan ve rolünü yapılandırmak isteyen kullanıcılar için
/// interaktif, adım adım kurulum ve rehber sihirbazı.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

enum _PrimaryRole { athlete, staff, guardian }

enum _AthleteType { licensed, individual }

enum _StaffType { coach, admin }

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  _PrimaryRole _selectedRole = _PrimaryRole.athlete;
  _AthleteType _athleteType = _AthleteType.licensed;
  _StaffType _staffType = _StaffType.coach;

  int get _totalSteps => _selectedRole == _PrimaryRole.athlete &&
          _athleteType == _AthleteType.licensed
      ? 6
      : 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    await markSetupWizardSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/akis');
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _goToVerification() async {
    await markSetupWizardSeen();
    if (!mounted) return;

    if (_selectedRole == _PrimaryRole.guardian) {
      Navigator.pushReplacementNamed(context, '/veli-bagla');
      return;
    }

    if (_selectedRole == _PrimaryRole.staff &&
        _staffType == _StaffType.admin) {
      Navigator.pushReplacementNamed(context, '/kulupler');
      return;
    }

    // 0: Antrenör, 1: Sporcu, 2: Kimlik
    final targetMode = _selectedRole == _PrimaryRole.staff ? 0 : 1;
    Navigator.pushReplacementNamed(
      context,
      '/dogrulama',
      arguments: targetMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Üst Kontrol Çubuğu (Geri, İlerleme, Şimdilik Atla)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.lg,
                vertical: SwanSpace.sm,
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: c.ink,
                      onPressed: _back,
                      tooltip: 'Geri',
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Adım ${_currentStep + 1} / $_totalSteps',
                          style: SwanType.caption(c.inkMuted),
                        ),
                        const SizedBox(height: SwanSpace.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: c.line,
                            valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Şimdilik Atla',
                      style: SwanType.bodySm(c.inkMuted, w: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // İçerik Sayfaları
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentStep = i),
                children: [
                  _buildWelcomeCard(c),
                  _buildPrimaryRoleCard(c),
                  _buildSubRoleCard(c),
                  _buildWhyVerifyCard(c),
                  if (_selectedRole == _PrimaryRole.athlete &&
                      _athleteType == _AthleteType.licensed)
                    _buildClubDiscoveryCard(c),
                  _buildFinalActionCard(c),
                ],
              ),
            ),

            // Alt Gezinme Butonları
            Container(
              padding: const EdgeInsets.all(SwanSpace.lg),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.ink,
                          side: BorderSide(color: c.line),
                          padding: const EdgeInsets.symmetric(
                            vertical: SwanSpace.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                        child: Text('Geri', style: SwanType.body(c.ink)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: SwanSpace.md),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _currentStep == _totalSteps - 1
                          ? _goToVerification
                          : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: SwanSpace.md,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                        ),
                      ),
                      child: Text(
                        _currentStep == _totalSteps - 1
                            ? 'Belgelerimi Yükle'
                            : 'Devam Et',
                        style: SwanType.body(
                          Colors.white,
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kart 0: Hoş Geldin & Uygulama Haritası (Neyin Nerede Olduğu)
  // ---------------------------------------------------------------------------
  Widget _buildWelcomeCard(SwanPalette c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.accentFill,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Icon(Icons.sports_rounded, color: c.accent, size: 28),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SwanSport\'a Hoş Geldin!', style: SwanType.h2(c.ink)),
                    const SizedBox(height: 2),
                    Text(
                      'Spor kulüpleri & sporcuların dijital yönetim ağı',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.lg),
          Text(
            'Uygulamada ne nerede, kısaca göz atalım:',
            style: SwanType.body(c.ink, w: FontWeight.w600),
          ),
          const SizedBox(height: SwanSpace.md),
          _featureRow(
            c,
            icon: Icons.stadium_rounded,
            title: 'Sahalar & Kortlar (Keşfet)',
            desc:
                'Çevrendeki halka açık kortları, halı sahaları ve boş saatleri gör, doğrudan sıraya gir.',
          ),
          _featureRow(
            c,
            icon: Icons.handshake_rounded,
            title: 'Partner Bul (Keşfet)',
            desc:
                'Kendi branşında ve seviyende maç yapacak oyuncularla eşleş, birlikte oyna.',
          ),
          _featureRow(
            c,
            icon: Icons.shield_rounded,
            title: 'Kulübüm & Takım',
            desc:
                'Antrenman programı, yoklamalar, maç sonuçları ve kulüp duyuruları tek ekranda.',
          ),
          _featureRow(
            c,
            icon: Icons.payments_rounded,
            title: 'Aidat & Finans',
            desc:
                'Kulüp aidatlarını takip et, dekont yükle; kulüp için şeffaf gelir-gider defteri.',
          ),
          _featureRow(
            c,
            icon: Icons.verified_user_rounded,
            title: 'Doğrulanmış Profil',
            desc:
                'Federasyon lisansın veya antrenör kademen onaylandığında profilinde resmi rozet parlar.',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kart 1: Rol Seçimi (Sen Kimsin?)
  // ---------------------------------------------------------------------------
  Widget _buildPrimaryRoleCard(SwanPalette c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SwanSport\'u nasıl kullanacaksın?', style: SwanType.h2(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          Text(
            'Sana en uygun özellikleri ve doğrulama aşamalarını hazırlamak için rolünü seç.',
            style: SwanType.bodySm(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.lg),
          _selectableCard(
            c,
            icon: Icons.directions_run_rounded,
            title: 'Sporcuyum',
            subtitle:
                'Antrenmanlara katılırım, maçlara çıkarım ya da partner arayarak spor yaparım.',
            selected: _selectedRole == _PrimaryRole.athlete,
            onTap: () => setState(() => _selectedRole = _PrimaryRole.athlete),
          ),
          const SizedBox(height: SwanSpace.md),
          _selectableCard(
            c,
            icon: Icons.admin_panel_settings_rounded,
            title: 'Kulüp Yetkilisiyim',
            subtitle:
                'Kulüpte antrenörlük yapıyorum veya kulübün yönetim ve idari işlerinden sorumluyum.',
            selected: _selectedRole == _PrimaryRole.staff,
            onTap: () => setState(() => _selectedRole = _PrimaryRole.staff),
          ),
          const SizedBox(height: SwanSpace.md),
          _selectableCard(
            c,
            icon: Icons.family_restroom_rounded,
            title: 'Sporcu Velisiyim',
            subtitle:
                'Çocuğumun kulüp antrenmanlarını, yoklama durumunu, aidatlarını ve sağlık izinlerini izleyeceğim.',
            selected: _selectedRole == _PrimaryRole.guardian,
            onTap: () => setState(() => _selectedRole = _PrimaryRole.guardian),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kart 2: Rol Detayı (Dallanma)
  // ---------------------------------------------------------------------------
  Widget _buildSubRoleCard(SwanPalette c) {
    if (_selectedRole == _PrimaryRole.athlete) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(SwanSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sporculuk durumun nedir?', style: SwanType.h2(c.ink)),
            const SizedBox(height: SwanSpace.xs),
            Text(
              'Lisanslı ya da ferdi olmana göre profil hakların şekillenir.',
              style: SwanType.bodySm(c.inkMuted),
            ),
            const SizedBox(height: SwanSpace.lg),
            _selectableCard(
              c,
              icon: Icons.workspace_premium_rounded,
              title: 'Lisanslı Sporcu',
              subtitle:
                'Resmi bir spor kulübünün sporcusuyum ve federasyon lisansım var.',
              selected: _athleteType == _AthleteType.licensed,
              onTap: () =>
                  setState(() => _athleteType = _AthleteType.licensed),
            ),
            const SizedBox(height: SwanSpace.md),
            _selectableCard(
              c,
              icon: Icons.fitness_center_rounded,
              title: 'Ferdi Sporcu',
              subtitle:
                'Bir kulübe bağlı değilim; bağımsız olarak antrenman yapıyor ve turnuvalara katılıyorum.',
              selected: _athleteType == _AthleteType.individual,
              onTap: () =>
                  setState(() => _athleteType = _AthleteType.individual),
            ),
          ],
        ),
      );
    } else if (_selectedRole == _PrimaryRole.staff) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(SwanSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kulüpteki görevin nedir?', style: SwanType.h2(c.ink)),
            const SizedBox(height: SwanSpace.xs),
            Text(
              'Teknik ekip ile kulüp yöneticilerinin araçları farklı yetkilere sahiptir.',
              style: SwanType.bodySm(c.inkMuted),
            ),
            const SizedBox(height: SwanSpace.lg),
            _selectableCard(
              c,
              icon: Icons.sports_tennis_rounded,
              title: 'Antrenör / Teknik Ekip',
              subtitle:
                'Sporcuları çalıştırıyorum; antrenman oturumu başlatacak ve yoklama alacağım.',
              selected: _staffType == _StaffType.coach,
              onTap: () => setState(() => _staffType = _StaffType.coach),
            ),
            const SizedBox(height: SwanSpace.md),
            _selectableCard(
              c,
              icon: Icons.account_balance_rounded,
              title: 'Kulüp Yöneticisi / Kurucusu',
              subtitle:
                'Kulübün idari, tescil, aidat ve harcama onay süreçlerini yöneteceğim.',
              selected: _staffType == _StaffType.admin,
              onTap: () => setState(() => _staffType = _StaffType.admin),
            ),
          ],
        ),
      );
    } else {
      // Veli Eşleştirme Detayı
      return SingleChildScrollView(
        padding: const EdgeInsets.all(SwanSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Veli Eşleştirme Rehberi', style: SwanType.h2(c.ink)),
            const SizedBox(height: SwanSpace.xs),
            Text(
              'Sporcu çocuğunun hesabına bağlanmak için gereken adımlar:',
              style: SwanType.bodySm(c.inkMuted),
            ),
            const SizedBox(height: SwanSpace.lg),
            _infoBox(
              c,
              icon: Icons.key_rounded,
              title: 'Kulüpten Davet Kodu Al',
              body:
                'Kulüp yöneticisi veya antrenör, çocuğun adına sistemden 6 haneli özel bir veli davet kodu üretir.',
            ),
            const SizedBox(height: SwanSpace.md),
            _infoBox(
              c,
              icon: Icons.link_rounded,
              title: 'Veli Bağla Menüsünden Kodu Gir',
              body:
                'Bu kodu Profil > Davet Kodu alanına girerek saniyeler içinde çocuğun hesabıyla bağlantı kurabilirsin.',
            ),
            const SizedBox(height: SwanSpace.md),
            _infoBox(
              c,
              icon: Icons.notifications_active_rounded,
              title: 'Canlı Bildirimleri Al',
              body:
                'Antrenman yoklamaları, sağlık durumu ve aidat bildirimleri telefonuna anında gelir.',
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Kart 3: Neden Kimlik & Belge Doğrulaması Gerekli?
  // ---------------------------------------------------------------------------
  Widget _buildWhyVerifyCard(SwanPalette c) {
    String roleTitle;
    String whyText;
    List<(String, String)> perks;
    List<String> requiredDocs;

    if (_selectedRole == _PrimaryRole.athlete) {
      final isLic = _athleteType == _AthleteType.licensed;
      roleTitle = isLic ? 'Lisanslı Sporcu Doğrulaması' : 'Ferdi Sporcu Doğrulaması';
      whyText =
          'Kimlik ve lisans doğrulaması neden zorunlu? İşte sağladığı haklar:';
      perks = [
        (
          'Resmi Müsabaka Kaydı',
          'Turnuva dereceleri ve maç istatistikleri doğrulanmış profiline işlenir.',
        ),
        (
          'Güven Rozeti',
          'Partner arama ve topluluklarda profilinde resmi onay rozeti görünür.',
        ),
        (
          'Tesis & Kort Ayrıcalıkları',
          'Anlaşmalı belediye ve kulüp tesislerinde lisanslı sporcu saatlerinden faydalanırsın.',
        ),
      ];
      requiredDocs = [
        'T.C. Kimlik Doğrulaması (Telefon / SMS veya Belge)',
        if (isLic) 'Federasyon Sporcu Lisansı (PDF / Fotoğraf)',
        'Spor Yapabilir Sağlık Raporu (varsa)',
      ];
    } else if (_selectedRole == _PrimaryRole.staff) {
      if (_staffType == _StaffType.coach) {
        roleTitle = 'Antrenörlük Belgesi Doğrulaması';
        whyText =
            'Antrenörlük yetkilerini açabilmen için federasyon belgen doğrulanmalıdır:';
        perks = [
          (
            'Yoklama & Antrenman Açma',
            'Takım antrenmanı başlatma ve karekodlu yoklama alma yetkisi.',
          ),
          (
            '1–5. Kademe Rozeti',
            'Federasyon onaylı kademen profilinde parlar ve antrenör bulma modülünde listelenirsin.',
          ),
          (
            'Performans Defteri',
            'Sporcularına özel çalışma şablonları ve hazırbulunuşluk takibi yapabilirsin.',
          ),
        ];
        requiredDocs = [
          'Federasyon Onaylı Antrenörlük Belgesi (Kademe & Vize)',
          'T.C. Kimlik / Telefon Doğrulaması',
        ];
      } else {
        roleTitle = 'Kulüp Yöneticisi Doğrulaması';
        whyText =
            'Kulüp açabilmek ve resmi işlemleri yürütebilmek için yetki belgesi istenir:';
        perks = [
          (
            'Resmi Kulüp Paneli',
            'Kulübünü SwanSport\'a tescil ettirip onaylı kulüp rozeti alma.',
          ),
          (
            'Mali Defter & Aidat',
            'Sporcu aidatlarını toplama, giderleri onaylama ve şeffaf kasa yönetimi.',
          ),
          (
            'Kadro & Antrenör Yetkilendirme',
            'Antrenörleri görevlendirme ve sporcuları kadroya dahil etme.',
          ),
        ];
        requiredDocs = [
          'Kulüp Tescil Belgesi / Dernek Karar Defteri Fotokopisi',
          'İmza Yetki Belgesi / Kulüp Görevlendirme Yazısı',
        ];
      }
    } else {
      roleTitle = 'Veli İzin & Güvenlik Kılavuzu';
      whyText =
          'Veli onayı 18 yaş altı sporcularımızın güvenliği için zorunludur:';
      perks = [
        (
          'Dijital Veli İzni',
          'Müsabaka ve seyahat izinlerini tek dokunuşla onaylayabilirsin.',
        ),
        (
          'Sağlık & Kısıt Takibi',
          'Sporcunun sağlık kısıtlarını doğrudan antrenöre iletebilirsin.',
        ),
      ];
      requiredDocs = [
        'Kulüpten Verilen 6 Haneli Davet Kodu',
        'Veli Telefon Numarası Doğrulaması',
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.md,
              vertical: SwanSpace.xs,
            ),
            decoration: BoxDecoration(
              color: c.accentFill,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Text(
              roleTitle,
              style: SwanType.caption(c.accent, w: FontWeight.w700),
            ),
          ),
          const SizedBox(height: SwanSpace.sm),
          Text('Neden belge girmelisin?', style: SwanType.h2(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          Text(whyText, style: SwanType.bodySm(c.inkMuted)),
          const SizedBox(height: SwanSpace.lg),
          for (final (title, desc) in perks) ...[
            _perkRow(c, title: title, desc: desc),
            const SizedBox(height: SwanSpace.sm),
          ],
          const SizedBox(height: SwanSpace.lg),
          Text(
            'Yüklemen Gerekecek Belgeler:',
            style: SwanType.body(c.ink, w: FontWeight.w700),
          ),
          const SizedBox(height: SwanSpace.sm),
          for (final doc in requiredDocs) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.attachment_rounded, size: 18, color: c.accent),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: Text(doc, style: SwanType.bodySm(c.ink)),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: SwanSpace.md),
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Icon(Icons.security_rounded, size: 20, color: c.inkMuted),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: Text(
                    'Belgelerin KVKK uyarınca şifreli depolanır. Yalnızca platform inceleme heyeti tarafından doğrulanır.',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kart 4: (Lisanslı Sporcu için) Kulübünü Bul / Katıl
  // ---------------------------------------------------------------------------
  Widget _buildClubDiscoveryCard(SwanPalette c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.md,
              vertical: SwanSpace.xs,
            ),
            decoration: BoxDecoration(
              color: c.accentFill,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Text(
              'Kulüp Bağlantısı',
              style: SwanType.caption(c.accent, w: FontWeight.w700),
            ),
          ),
          const SizedBox(height: SwanSpace.sm),
          Text('Kulübün SwanSport\'ta mı?', style: SwanType.h2(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          Text(
            'SwanSport\'a kayıtlı kulüpleri arayabilir, kendi kulübünü bularak kadroya katılma isteği gönderebilirsin.',
            style: SwanType.bodySm(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.lg),
          Container(
            padding: const EdgeInsets.all(SwanSpace.lg),
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
                    Icon(Icons.search_rounded, color: c.accent, size: 26),
                    const SizedBox(width: SwanSpace.sm),
                    Text(
                      'Kulüpleri Ara & İncele',
                      style: SwanType.h3(c.ink),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.sm),
                Text(
                  'Kulübünü bulduğunda "Katılma Başvurusu" yapabilirsin. Kulüp yöneticin onayladığında otomatik olarak takım kadrosuna ve antrenman takvimine bağlanırsın.',
                  style: SwanType.bodySm(c.inkMuted),
                ),
                const SizedBox(height: SwanSpace.md),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/kulupler');
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Kulüpleri İncele'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: c.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kart 5: Kurulum Özeti & Eyleme Geçiş
  // ---------------------------------------------------------------------------
  Widget _buildFinalActionCard(SwanPalette c) {
    String selectedRoleSummary;
    if (_selectedRole == _PrimaryRole.athlete) {
      selectedRoleSummary = _athleteType == _AthleteType.licensed
          ? 'Lisanslı Sporcu'
          : 'Ferdi Sporcu';
    } else if (_selectedRole == _PrimaryRole.staff) {
      selectedRoleSummary = _staffType == _StaffType.coach
          ? 'Antrenör / Teknik Ekip'
          : 'Kulüp Yöneticisi';
    } else {
      selectedRoleSummary = 'Sporcu Velisi';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.successFill,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: c.success, size: 32),
          ),
          const SizedBox(height: SwanSpace.md),
          Text('Kurulum Rehberi Tamamlandı!', style: SwanType.h2(c.ink)),
          const SizedBox(height: SwanSpace.xs),
          Text(
            'Seçtiğin profil: $selectedRoleSummary. Şimdi nasıl devam etmek istersin?',
            style: SwanType.body(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.lg),
          Container(
            padding: const EdgeInsets.all(SwanSpace.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seçenek 1: Belgelerini Şimdi Yükle',
                  style: SwanType.body(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Doğrulama sayfasına geçerek kimlik, antrenörlük ya da lisans evraklarını hemen yükle ve incelemeye gönder.',
                  style: SwanType.bodySm(c.inkMuted),
                ),
                const SizedBox(height: SwanSpace.md),
                ElevatedButton.icon(
                  onPressed: _goToVerification,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('Doğrulama Sayfasına Git'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          Container(
            padding: const EdgeInsets.all(SwanSpace.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seçenek 2: Şimdilik Keşfet',
                  style: SwanType.body(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Belgelerini daha sonra istediğin zaman Profil > Doğrulama adımlarından yükleyebilirsin.',
                  style: SwanType.bodySm(c.inkMuted),
                ),
                const SizedBox(height: SwanSpace.md),
                OutlinedButton.icon(
                  onPressed: _skip,
                  icon: const Icon(Icons.explore_rounded, size: 18),
                  label: const Text('Ana Sayfaya Geç'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink,
                    side: BorderSide(color: c.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Yardımcı Bileşenler
  // ---------------------------------------------------------------------------
  Widget _featureRow(
    SwanPalette c, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
              border: Border.all(color: c.line),
            ),
            child: Icon(icon, color: c.accent, size: 20),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SwanType.body(c.ink, w: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectableCard(
    SwanPalette c, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: selected ? c.accentFill : c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(
            color: selected ? c.accent : c.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(SwanSpace.sm),
              decoration: BoxDecoration(
                color: selected ? c.accent : c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : c.ink,
                size: 24,
              ),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SwanType.body(
                      selected ? c.accent : c.ink,
                      w: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: c.accent, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(
    SwanPalette c, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.accent, size: 22),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _perkRow(SwanPalette c, {required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_rounded, size: 18, color: c.success),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
              Text(desc, style: SwanType.caption(c.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

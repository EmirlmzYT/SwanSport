import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// İlk açılış tanıtımı — üç kart, bir kez.
///
/// **Neden var:** uygulamayı ilk açan kişi doğrudan giriş ekranını görüyordu.
/// Orada yazan tek şey "Profesyonel spor yönetim platformu"; ne yaptığı,
/// kulübü olmayan birine ne sunduğu belli değildi. Oysa uygulamanın en geniş
/// kitleye açılan kapısı (kortlar, halı sahalar, partner bulma) **kulüp
/// gerektirmiyor** — bunu giriş ekranından anlamanın yolu yok.
///
/// Bir kez gösterilir; `shared_preferences`'ta bir bayrak tutuluyor. Atlanabilir
/// olması şart: uygulamayı yeniden kuran mevcut kullanıcıyı üç ekran boyunca
/// bekletmek, tanıtımın değerinden fazla can sıkıyor.
const kOnboardingSeenKey = 'onboarding_seen_v1';

/// Tanıtımın görülüp görülmediği. Okunamazsa **görülmüş sayılır** —
/// `shared_preferences` bir sebeple açılmazsa kullanıcıyı her açılışta
/// tanıtıma düşürmektense hiç göstermemek daha az zarar verir.
Future<bool> onboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kOnboardingSeenKey) ?? false;
  } catch (_) {
    return true;
  }
}

Future<void> markOnboardingSeen() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingSeenKey, true);
  } catch (_) {
    // Yazılamadıysa tanıtım bir daha çıkar; kırılan bir şey yok.
  }
}

class OnboardingPage {
  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// Metinler özellik listesi değil, **kullanıcının işi** üzerinden yazıldı.
/// "Sosyal akış modülü" değil "kulübünde olan biteni gör" — brief §1'in kuralı.
const kOnboardingPages = [
  OnboardingPage(
    icon: Icons.sports_tennis_rounded,
    title: 'Nerede oynayacağını bul',
    body: 'Yakınındaki halka açık kortların ve halı sahaların hangi saatleri '
        'boş, gitmeden gör. Sıraya evinden gir.',
  ),
  OnboardingPage(
    icon: Icons.handshake_rounded,
    title: 'Partnerin yoksa da oyna',
    body: 'Aynı branşta oynamak isteyenlere haber gider. Kabul eden çıkarsa '
        'mesajlaşıp saatinizi ayarlarsınız.',
  ),
  OnboardingPage(
    icon: Icons.groups_rounded,
    title: 'Kulübün varsa hepsi burada',
    body: 'Antrenman programı, yoklama, aidat ve performans tek yerde. '
        'Kulübün yoksa da uygulamanın yarısı sana açık.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onDone, super.key});

  /// Tanıtım bitince ne olacağını çağıran taraf söyler — bu ekran kendi
  /// başına gezinmiyor. Böylece hem ilk açılışta hem Ayarlar'dan tekrar
  /// gösterilebiliyor.
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (mounted) widget.onDone();
  }

  void _next() {
    if (_page >= kOnboardingPages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final last = _page == kOnboardingPages.length - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text('Atla',
                        style: SwanType.bodySm(c.inkMuted,
                            w: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: kOnboardingPages.length,
                    itemBuilder: (_, i) => _Page(page: kOnboardingPages[i]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < kOnboardingPages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _page ? c.accent : c.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      SwanSpace.xl, 0, SwanSpace.xl, SwanSpace.xl),
                  child: GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // Üstünde beyaz metin var: `accent` değil `accentFill`.
                        color: c.accentFill,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      child: Text(last ? 'Başla' : 'Devam',
                          style: SwanType.body(Colors.white,
                              w: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(SwanRadius.lg),
            ),
            child: Icon(page.icon, size: 44, color: c.accent),
          ),
          const SizedBox(height: SwanSpace.xl),
          Text(page.title,
              textAlign: TextAlign.center, style: SwanType.h1(c.ink)),
          const SizedBox(height: SwanSpace.md),
          Text(page.body,
              textAlign: TextAlign.center,
              style: SwanType.body(c.inkMuted)),
        ],
      ),
    );
  }
}

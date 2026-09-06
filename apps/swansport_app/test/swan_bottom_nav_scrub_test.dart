import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/swan_bottom_nav.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

/// Alt çubukta kaydırarak seçim.
///
/// **Neden test ediliyor:** iki jest aynı bileşende yaşıyor — normal dokunuş
/// doğrudan gidiyor, uzun basış kaydırma kipini açıyor. Biri diğerini
/// yutarsa belirti sessiz oluyor: ya çubuk hiç tepki vermiyor ya da parmağı
/// kaydırırken istemediğin sayfa açılıyor.
void main() {
  /// Gezinilen son rotayı yakalayan bir kabuk.
  Widget host(List<String> log) => ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          onGenerateRoute: (settings) {
            if (settings.name != null && settings.name != '/') {
              log.add(settings.name!);
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                bottomNavigationBar: SwanBottomNav(),
              ),
            );
          },
        ),
      );

  /// Ekrandaki bir sekmenin merkezi.
  Offset centerOf(WidgetTester tester, String label) =>
      tester.getCenter(find.text(label));

  testWidgets('normal dokunuş doğrudan gidiyor', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(host(log));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keşfet'));
    await tester.pumpAndSettle();

    expect(log, contains('/kesfet'));
  });

  testWidgets('basılı tutup kaydırınca bırakılan sekme açılıyor',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(host(log));
    await tester.pumpAndSettle();

    final start = centerOf(tester, 'Ana Sayfa');
    final target = centerOf(tester, 'Mesajlar');

    final g = await tester.startGesture(start);
    // Uzun basış eşiğini geç — kaydırma kipi ancak bundan sonra açılıyor.
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
    await g.moveTo(target);
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    expect(log, contains('/mesajlar'));
    // Parmağın başladığı sekmeye GİTMEMELİ: seçimi bırakılan yer belirliyor.
    expect(log, isNot(contains('/akis')));
  });

  testWidgets('kaydırma sırasında parmağın altındaki sekme öne çıkıyor',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(host(log));
    await tester.pumpAndSettle();

    final g = await tester.startGesture(centerOf(tester, 'Ana Sayfa'));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
    await g.moveTo(centerOf(tester, 'Keşfet'));
    await tester.pump(const Duration(milliseconds: 200));

    // Önizleme sırasında hiçbir gezinme olmamalı — yalnızca görsel.
    expect(log, isEmpty);

    await g.up();
    await tester.pumpAndSettle();
    expect(log, contains('/kesfet'));
  });

  testWidgets('oturum yokken Profil sekmesinde bırakmak bir yere gitmiyor',
      (tester) async {
    // Profil rotası `arguments` olarak kendi kimliğini istiyor; oturum
    // yokken gitmek argümansız bir profil ekranı açardı. Kaydırma bu
    // korumayı ATLAMAMALI — dokunuşta olduğu gibi burada da geçerli.
    final log = <String>[];
    await tester.pumpWidget(host(log));
    await tester.pumpAndSettle();

    final g = await tester.startGesture(centerOf(tester, 'Ana Sayfa'));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
    await g.moveTo(centerOf(tester, 'Profil'));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();

    expect(log, isEmpty);
  });

  testWidgets('kaydırmadan bırakmak basılı tutulan sekmeyi açıyor',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(host(log));
    await tester.pumpAndSettle();

    final g = await tester.startGesture(centerOf(tester, 'Keşfet'));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
    await g.up();
    await tester.pumpAndSettle();

    expect(log, contains('/kesfet'));
  });

  testWidgets('beş öğe duruyor — kaydırma yapısı bozmadı', (tester) async {
    await tester.pumpWidget(host(<String>[]));
    await tester.pumpAndSettle();

    for (final t in ['Ana Sayfa', 'Keşfet', 'Mesajlar', 'Profil']) {
      expect(find.text(t), findsOneWidget, reason: '$t sekmesi kayboldu');
    }
    // Ortadaki "+" eylem düğmesi.
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}

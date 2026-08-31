import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/swan_skeleton.dart';

/// Yükleniyor iskeleti.
///
/// `premiumLoading()` bunu 39 ekranda kullanıyor — burada kırılan şey
/// uygulamanın her yerinde kırılır. Animasyonlu olduğu için sessizce
/// bozulması kolay: `AnimationController` sızdırırsa ya da çizim
/// patlarsa yalnızca çalışırken görünür.
void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: child),
      );

  testWidgets('iskelet çizilir ve istenen satır sayısını üretir',
      (tester) async {
    await tester.pumpWidget(wrap(const SwanListSkeleton(rows: 4)));

    // Satır başına iki metin bloğu + bir avatar = 3 parıltı.
    expect(find.byType(SwanShimmer), findsNWidgets(4 * 3));
  });

  testWidgets('koyu temada da patlamadan çizilir', (tester) async {
    await tester.pumpWidget(
        wrap(const SwanListSkeleton(rows: 2), brightness: Brightness.dark));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(SwanShimmer), findsNWidgets(6));
  });

  testWidgets('animasyon ilerler ve hata vermez', (tester) async {
    await tester.pumpWidget(wrap(const SwanShimmer(width: 100, height: 12)));

    // Döngünün ortasına ve sonuna kadar ilerlet.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('widget kaldırılınca denetleyici sızdırmaz', (tester) async {
    await tester.pumpWidget(wrap(const SwanShimmer(width: 100, height: 12)));
    await tester.pump(const Duration(milliseconds: 200));

    // Boş bir ağaca geçmek dispose'u tetikler; sızıntı olsaydı
    // pumpWidget sonrası test biterken hata verirdi.
    await tester.pumpWidget(wrap(const SizedBox()));
    expect(tester.takeException(), isNull);
  });
}

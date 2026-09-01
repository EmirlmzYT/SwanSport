import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/pending_work.dart';

/// Sprint 2 — takım merkezi ve bekleyen işler.
///
/// Buradaki asıl iddia şu: **bekleyen bir şey yoksa kutu hiç çizilmemeli.**
/// "Her şey yolunda" kutusu ekranı kalabalıklaştırıyor ve göz onu atlamayı
/// öğreniyor; asıl bir şey belirdiğinde de atlıyor. Bu, gözle bakınca fark
/// edilmeyen ama zamanla özelliği işe yaramaz hale getiren bir karar.
void main() {
  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('bekleyen iş yokken hiçbir şey çizilmiyor', (tester) async {
    // Sağlayıcılar Supabase olmadan boş dönüyor: "bekleyen yok" durumu.
    await tester.pumpWidget(host(const PendingWork()));
    await tester.pump();

    expect(find.text('Bekleyen işler'), findsNothing);
    // Boş bir SizedBox dışında hiçbir görsel öğe olmamalı.
    expect(find.byType(Container), findsNothing);
  });

  testWidgets('render çökmüyor ve koyu temada da çalışıyor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: PendingWork()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

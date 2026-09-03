import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/widgets/getting_started_card.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

/// Yeni sporcunun "Başlarken" bloğu.
///
/// Bu bloğun tek işi **kaybolmak**: verisi olan sporcunun ekranında hiç
/// görünmemeli. Görünmeye devam ederse ana ekranın üstünde kalıcı bir
/// eğitim kutusu olur ve tam tersi etkiyi yapar.
void main() {
  Widget host(AthleteCard? card) => ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: Scaffold(body: GettingStartedCard(card: card)),
        ),
      );

  AthleteCard card({
    int trainings = 0,
    int goalsActive = 0,
    int achievements = 0,
    String? clubName,
  }) =>
      AthleteCard.fromMap({
        'trainings': trainings,
        'attendance_pct': 0,
        'goals_done': 0,
        'goals_active': goalsActive,
        'achievements': achievements,
        'club_name': clubName,
      });

  testWidgets('veri yokken çiziliyor', (tester) async {
    await tester.pumpWidget(host(card(clubName: 'Konya OK')));
    await tester.pump();

    expect(find.text('Başlarken'), findsOneWidget);
    expect(find.text('Belgelerim'), findsOneWidget);
    expect(find.text('Doğrulama'), findsOneWidget);
  });

  testWidgets('tek bir antrenman bile kaydedilmişse kayboluyor',
      (tester) async {
    await tester.pumpWidget(host(card(trainings: 1, clubName: 'Konya OK')));
    await tester.pump();

    expect(find.text('Başlarken'), findsNothing);
  });

  testWidgets('açık hedefi olan sporcuda kayboluyor', (tester) async {
    // `hasData` yalnızca antrenmana bakmıyor; hedef ya da başarı da
    // "bu sporcu başlamış" demek.
    await tester.pumpWidget(host(card(goalsActive: 2)));
    await tester.pump();

    expect(find.text('Başlarken'), findsNothing);
  });

  testWidgets('kazanılmış başarısı olan sporcuda kayboluyor', (tester) async {
    await tester.pumpWidget(host(card(achievements: 1)));
    await tester.pump();

    expect(find.text('Başlarken'), findsNothing);
  });

  testWidgets('kart henüz yüklenmemişken çizilmiyor', (tester) async {
    // Yüklenirken bir an gösterip veri gelince gizlemek, ekranın
    // zıplamasına yol açardı.
    await tester.pumpWidget(host(null));
    await tester.pump();

    expect(find.text('Başlarken'), findsNothing);
  });

  testWidgets('kulübü olmayan sporcuya farklı metin gösteriliyor',
      (tester) async {
    // Kulüpsüz birine "ilk antrenmanından sonra" demek yanlış olurdu —
    // önce bir kulübe katılması gerekiyor.
    await tester.pumpWidget(host(card()));
    await tester.pump();

    expect(find.textContaining('kulübe katıldığında'), findsOneWidget);
  });

  testWidgets('kulübü olan sporcuya antrenman metni gösteriliyor',
      (tester) async {
    await tester.pumpWidget(host(card(clubName: 'Konya OK')));
    await tester.pump();

    expect(find.textContaining('İlk antrenmanından sonra'), findsOneWidget);
  });

  testWidgets('bayrak kapalıyken antrenman kısayolu çizilmiyor',
      (tester) async {
    // featureEnabledProvider varsayılan olarak kapalı (fixture modu):
    // bayrak açılmadan sporcuya olmayan bir ekranın kapısı gösterilmemeli.
    await tester.pumpWidget(host(card(clubName: 'Konya OK')));
    await tester.pump();

    expect(find.text('Antrenmanlarım'), findsNothing);
  });
}

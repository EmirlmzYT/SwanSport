import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> render(
    WidgetTester tester, {
    int initialTab = 0,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(false),
          currentProfileProvider.overrideWith((_) async => null),
          conversationsProvider.overrideWith((_) async => []),
          communityListProvider.overrideWith((_) async => []),
          ...overrides,
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MessagesScreen(initialTab: initialTab),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Modern mesajlar arayüzü başlık, butonlar ve filtre jetonlarını gösterir', (tester) async {
    await render(tester);

    expect(find.text('Mesajlar'), findsOneWidget);
    expect(find.byTooltip('Yeni Grup veya Kişi'), findsOneWidget);
    expect(find.byTooltip('Yeni Sohbet'), findsOneWidget);

    expect(find.text('Kişi, grup veya kulüp ara...'), findsOneWidget);

    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('Gruplar'), findsOneWidget);
    expect(find.text('Kulüpler'), findsOneWidget);
    expect(find.text('Antrenörler'), findsOneWidget);

    // Referans tasarımdaki kilit sohbetler listelenmeli
    expect(find.text('U12 Takım Grubu'), findsOneWidget);
    expect(find.text('Ahmet Demir'), findsOneWidget);
    expect(find.text('Swan Spor Kulübü'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Veli Grubu'), findsOneWidget);
    expect(find.text('Federasyon'), findsOneWidget);
    expect(find.text('Malzeme Ekibi'), findsOneWidget);

    // Rozet ve sessize alma simgeleri
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('Kategori filtreleri doğru sohbet grubunu filtreler', (tester) async {
    await render(tester);

    // Gruplar filtresine tıkla
    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();

    expect(find.text('U12 Takım Grubu'), findsOneWidget);
    expect(find.text('Veli Grubu'), findsOneWidget);
    expect(find.text('U14 Takımı'), findsOneWidget);
    expect(find.text('Ahmet Demir'), findsNothing);
    expect(find.text('Swan Spor Kulübü'), findsNothing);

    // Kulüpler filtresine tıkla
    await tester.tap(find.text('Kulüpler'));
    await tester.pumpAndSettle();

    expect(find.text('Swan Spor Kulübü'), findsOneWidget);
    expect(find.text('Federasyon'), findsOneWidget);
    expect(find.text('Malzeme Ekibi'), findsOneWidget);
    expect(find.text('U12 Takım Grubu'), findsNothing);
    expect(find.text('Zeynep Kaya'), findsNothing);

    // Antrenörler filtresine tıkla
    await tester.ensureVisible(find.text('Antrenörler'));
    await tester.tap(find.text('Antrenörler'));
    await tester.pumpAndSettle();

    expect(find.text('Ahmet Demir'), findsOneWidget);
    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Mehmet Arslan'), findsOneWidget);
    expect(find.text('Elif Yılmaz'), findsOneWidget);
    expect(find.text('Swan Spor Kulübü'), findsNothing);
  });

  testWidgets('Arama kutusu anlık olarak eşleşen sohbetleri filtreler', (tester) async {
    await render(tester);

    await tester.enterText(find.byType(TextField), 'Zeynep');
    await tester.pumpAndSettle();

    expect(find.text('Zeynep Kaya'), findsOneWidget);
    expect(find.text('Ahmet Demir'), findsNothing);
    expect(find.text('U12 Takım Grubu'), findsNothing);

    // Temizleme ikonuna tıklandığında liste geri gelir
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Ahmet Demir'), findsOneWidget);
  });

  testWidgets('initialTab 1 doğrudan Gruplar filtresini seçili başlatır', (tester) async {
    await render(tester, initialTab: 1);

    expect(find.text('U12 Takım Grubu'), findsOneWidget);
    expect(find.text('Veli Grubu'), findsOneWidget);
    expect(find.text('Ahmet Demir'), findsNothing);
  });
}

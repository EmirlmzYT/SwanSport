import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final List<ConversationRow> sampleDms = [
    ConversationRow(
      otherId: 'coach-1',
      otherName: 'Başantrenör Ali',
      lastBody: 'Yarınki antrenman saatinde değişiklik var.',
      lastAt: DateTime.now().subtract(const Duration(minutes: 15)),
      unread: 3,
    ),
    ConversationRow(
      otherId: 'athlete-1',
      otherName: 'Can Yılmaz',
      lastBody: 'Formamı teslim aldım, teşekkürler.',
      lastAt: DateTime.now().subtract(const Duration(hours: 2)),
      unread: 0,
    ),
  ];

  final List<CommunityRow> sampleGroups = [
    CommunityRow(
      id: 'group-1',
      name: 'Yüzme Takımı Grubu',
      cityName: 'İstanbul',
      memberCount: 24,
      unread: 0,
      joined: true,
      lastBody: 'Haftalık program yayımlandı.',
      lastAt: DateTime.now().subtract(const Duration(days: 1)),
      kind: 'city_coach',
    ),
    CommunityRow(
      id: 'fed-1',
      name: 'Yüzme Federasyonu Duyuru Kanalı',
      cityName: 'Ankara',
      memberCount: 350,
      unread: 0,
      joined: true,
      lastBody: 'Ulusal yarışma takvimi güncellendi.',
      lastAt: DateTime.now().subtract(const Duration(days: 2)),
      kind: 'federation',
    ),
  ];

  Future<void> render(
    WidgetTester tester, {
    int initialTab = 0,
    List<ConversationRow>? dms,
    List<CommunityRow>? groups,
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
          conversationsProvider.overrideWith((_) async => dms ?? sampleDms),
          communityListProvider.overrideWith((_) async => groups ?? sampleGroups),
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

  testWidgets('Modern mesajlar arayüzü başlık, aksiyonlar, arama ve filtre jetonlarını gösterir', (tester) async {
    await render(tester);

    expect(find.text('Mesajlar'), findsOneWidget);
    expect(find.byTooltip('Yeni Grup veya Kişi'), findsOneWidget);
    expect(find.byTooltip('Yeni Sohbet'), findsOneWidget);

    expect(find.text('Kişi, grup veya kulüp ara...'), findsOneWidget);

    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('Gruplar'), findsOneWidget);
    expect(find.text('Kulüpler'), findsOneWidget);
    expect(find.text('Antrenörler'), findsOneWidget);

    // Gerçek konuşmalar ve gruplar listelenir
    expect(find.text('Başantrenör Ali'), findsOneWidget);
    expect(find.text('Can Yılmaz'), findsOneWidget);
    expect(find.text('Yüzme Takımı Grubu'), findsOneWidget);
    expect(find.text('Yüzme Federasyonu Duyuru Kanalı'), findsOneWidget);

    // Okunmamış mesaj rozeti
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Kategori filtreleri gerçek grupları ve diyalogları doğru ayırır', (tester) async {
    await render(tester);

    // Gruplar filtresine tıkla
    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();

    expect(find.text('Yüzme Takımı Grubu'), findsOneWidget);
    expect(find.text('Başantrenör Ali'), findsNothing);
    expect(find.text('Yüzme Federasyonu Duyuru Kanalı'), findsNothing);

    // Kulüpler/Federasyon filtresine tıkla
    await tester.tap(find.text('Kulüpler'));
    await tester.pumpAndSettle();

    expect(find.text('Yüzme Federasyonu Duyuru Kanalı'), findsOneWidget);
    expect(find.text('Yüzme Takımı Grubu'), findsNothing);
    expect(find.text('Başantrenör Ali'), findsNothing);

    // Antrenörler/Diyalog filtresine tıkla
    await tester.ensureVisible(find.text('Antrenörler'));
    await tester.tap(find.text('Antrenörler'));
    await tester.pumpAndSettle();

    expect(find.text('Başantrenör Ali'), findsOneWidget);
    expect(find.text('Can Yılmaz'), findsOneWidget);
    expect(find.text('Yüzme Takımı Grubu'), findsNothing);
  });

  testWidgets('Arama kutusu anlık olarak gerçek sohbetleri filtreler', (tester) async {
    await render(tester);

    await tester.enterText(find.byType(TextField), 'Ali');
    await tester.pumpAndSettle();

    expect(find.text('Başantrenör Ali'), findsOneWidget);
    expect(find.text('Can Yılmaz'), findsNothing);
    expect(find.text('Yüzme Takımı Grubu'), findsNothing);

    // Temizle
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Can Yılmaz'), findsOneWidget);
  });

  testWidgets('Hiç mesaj olmadığında temiz boş durum gösterir', (tester) async {
    await render(tester, dms: const [], groups: const []);

    expect(find.text('Henüz mesajınız yok'), findsOneWidget);
    expect(find.text('Kullanıcı Ara & Sohbet Başlat'), findsOneWidget);
  });
}

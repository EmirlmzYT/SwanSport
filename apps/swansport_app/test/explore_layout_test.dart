import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/network/presentation/explore_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('Keşfet gerçek içerikleri sade hiyerarşiyle gösterir',
      (tester) async {
    final boundary = GlobalKey();
    await _pumpExplore(tester, const Size(390, 844), boundary: boundary);

    expect(find.text('Kimi veya neyi arıyorsun?'), findsOneWidget);
    expect(find.text('Kulüp bul'), findsOneWidget);
    expect(find.text('Antrenör bul'), findsOneWidget);
    expect(find.text('Saha bul'), findsOneWidget);
    expect(find.text('Partner bul'), findsOneWidget);
    expect(find.text('Antrenmanlarım'), findsNothing);
    expect(find.text('Keşfedilecek kulüpler'), findsOneWidget);
    expect(find.text('Sporcular ve antrenörler'), findsOneWidget);
    expect(find.text('Yaklaşan organizasyonlar'), findsOneWidget);
    expect(find.text('Geçmiş Turnuva'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/explore-mobile.png'),
    );
    await tester.ensureVisible(find.byKey(const Key('all-categories-button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('all-categories-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Organizasyonlar'), findsOneWidget);
    expect(find.text('Topluluklar'), findsOneWidget);
    expect(find.text('İlanlar'), findsOneWidget);
    expect(find.text('Federasyon'), findsOneWidget);
    expect(find.text('Canlı skor'), findsOneWidget);
    expect(find.text('Pazaryeri'), findsOneWidget);
  });

  testWidgets('Keşfet geniş web görünümünde taşma yapmaz', (tester) async {
    final boundary = GlobalKey();
    await _pumpExplore(tester, const Size(1440, 900), boundary: boundary);
    expect(find.text('Kulüp bul'), findsOneWidget);
    expect(find.text('Partner bul'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/explore-wide.png'),
    );
  });

  testWidgets('Keşfet 320 piksel ve 2x metinde tek sütuna uyum sağlar',
      (tester) async {
    await _pumpExplore(tester, const Size(320, 568), textScale: 2);
    expect(find.text('Kulüp bul'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const Key('explore-scroll-view')),
      const Offset(0, -500),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpExplore(
  WidgetTester tester,
  Size size, {
  GlobalKey? boundary,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final child = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: const ExploreScreen(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: boundary == null
          ? child
          : RepaintBoundary(key: boundary, child: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

List<Override> _overrides() => [
      swanAccessProvider.overrideWithValue(
        const SwanAccess(
          isPlatformAdmin: false,
          clubRole: null,
          coachLevel: 0,
          athleteKind: null,
        ),
      ),
      featureFlagsProvider.overrideWith(
        (ref) async => const FeatureFlags({
          FeatureFlags.coachDiscovery,
          FeatureFlags.courts,
          FeatureFlags.partnerSearch,
          FeatureFlags.liveMatchHub,
          FeatureFlags.marketplace,
        }),
      ),
      unreadNotificationsProvider.overrideWith((ref) async => 0),
      unreadMessagesProvider.overrideWith((ref) async => 0),
      hiddenProfilesProvider.overrideWith((ref) async => <String>{}),
      discoverClubsProvider(const DiscoverFilter()).overrideWith(
        (ref) async => const [
          DiscoveredClub(
            id: 'club-1',
            name: 'Boğaziçi Yüzme Kulübü',
            athleteCount: 86,
            coachCount: 7,
            isVerified: true,
            isFollowing: false,
            sportName: 'Yüzme',
            city: 'İstanbul',
          ),
          DiscoveredClub(
            id: 'club-2',
            name: 'Anka Atletizm',
            athleteCount: 42,
            coachCount: 4,
            isVerified: true,
            isFollowing: false,
            sportName: 'Atletizm',
            city: 'Ankara',
          ),
        ],
      ),
      suggestionsProvider.overrideWith(
        (ref) async => const [
          SuggestionRow(
            id: 'coach-1',
            name: 'Selin Kaya',
            kind: 'coach',
            subtitle: 'Yüzme • 2. Kademe Antrenör',
          ),
          SuggestionRow(
            id: 'athlete-1',
            name: 'Deniz Yılmaz',
            kind: 'athlete',
            subtitle: 'Atletizm',
          ),
          SuggestionRow(
            id: 'club-hidden',
            name: 'Tekrarlanan Kulüp',
            kind: 'club',
          ),
        ],
      ),
      organizationsProvider('').overrideWith(
        (ref) async => [
          Organization(
            id: 'org-1',
            name: 'Kış Yüzme Kupası',
            kind: 'cup',
            status: 'open',
            participantCount: 18,
            canManage: false,
            sportName: 'Yüzme',
            cityName: 'İstanbul',
            startsOn: DateTime.now().add(const Duration(days: 30)),
          ),
          Organization(
            id: 'org-old',
            name: 'Geçmiş Turnuva',
            kind: 'tournament',
            status: 'finished',
            participantCount: 8,
            canManage: false,
            startsOn: DateTime.now().subtract(const Duration(days: 30)),
          ),
        ],
      ),
      announcementsProvider.overrideWith(
        (ref) async => [
          AnnouncementRow(
            title: 'Kritik: Tesis çalışma saati değişti',
            body: 'Cumartesi günü tesis saat 10.00’da açılacaktır.',
            pinned: true,
            createdAt: DateTime.now(),
          ),
          AnnouncementRow(
            title: 'Yeni sezon programı',
            body: 'Antrenman programı kulüp takviminde yayımlandı.',
            pinned: false,
            createdAt: DateTime.now(),
          ),
        ],
      ),
      discoverProvider.overrideWith(
        (ref) async => [
          PostRow(
            id: 'post-1',
            authorId: 'club-author',
            authorName: 'Boğaziçi Yüzme Kulübü',
            clubId: 'club-1',
            clubName: 'Boğaziçi Yüzme Kulübü',
            body: 'Hafta sonu açık antrenmanımıza tüm sporcular davetlidir.',
            createdAt: DateTime.now(),
          ),
        ],
      ),
    ];

Future<void> _capture(GlobalKey key, String path) async {
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await Directory(path.substring(0, path.lastIndexOf('/')))
      .create(recursive: true);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

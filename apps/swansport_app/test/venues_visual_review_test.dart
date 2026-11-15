import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/courts/presentation/court_detail_screen.dart';
import 'package:swansport_app/features/courts/presentation/venues_screen.dart';
import 'package:swansport_app/features/turf/presentation/turf_field_detail_screen.dart';
import 'package:swansport_data/swansport_data.dart';

bool _isUnavailableAppLinks(Object? error) =>
    error is MissingPluginException &&
    error.message?.contains('com.llfbandit.app_links/events') == true;

class _Courts extends Fake implements CourtService {
  @override
  Future<String> claimSlot({
    required String courtId,
    required DateTime startsAt,
    int guests = 0,
    int needed = 0,
  }) async =>
      'slot-new';
}

class _Turf extends Fake implements TurfService {
  @override
  Future<void> requestSlot({
    required String fieldId,
    required DateTime startsAt,
  }) async {}
}

class _OccupiedCourts extends Fake implements CourtService {
  @override
  Future<String> claimSlot({
    required String courtId,
    required DateTime startsAt,
    int guests = 0,
    int needed = 0,
  }) =>
      Future.error(Exception('message: Saat dolu,'));
}

final _start = DateTime(2026, 11, 9, 19);

const _court = Court(
  id: 'court-1',
  name: '1 Nolu Merkez Kortu',
  venue: 'Meram Spor Kompleksi',
  district: 'Meram',
  cityName: 'Konya',
  sportCode: 'tennis',
  sportName: 'Tenis',
  surfaceType: 'Sert zemin',
  lat: 37.87,
  lng: 32.48,
  opensAt: '08:00',
  closesAt: '23:00',
  capacity: 4,
);

const _secondCourt = Court(
  id: 'court-2',
  name: '2 Nolu Açık Kort',
  venue: 'Meram Spor Kompleksi',
  district: 'Meram',
  cityName: 'Konya',
  sportCode: 'tennis',
  sportName: 'Tenis',
  lat: 37.87,
  lng: 32.48,
  opensAt: '08:00',
  closesAt: '23:00',
  capacity: 4,
);

const _field = TurfField(
  id: 'field-1',
  name: 'Şampiyonlar Sahası',
  venueName: 'Selçuklu Spor Tesisleri',
  district: 'Selçuklu',
  cityName: 'Konya',
  surfaceType: 'Suni çim',
  opensAt: '09:00',
  closesAt: '24:00',
);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('Sora')
          ..addFont(rootBundle.load('assets/fonts/Sora-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Sora-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Sora-Bold.ttf')))
        .load();
    await (FontLoader('Plus Jakarta Sans')
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'),
          )
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'),
          ))
        .load();
    // google_fonts uses the package family alias in explicitly styled widgets
    // (for example SwanSegmentedTabs), while the app theme uses the display
    // family above. Load both so visual-review captures render real labels.
    await (FontLoader('Plus_Jakarta_Sans')
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'),
          )
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'),
          ))
        .load();
    await (FontLoader('PlusJakartaSans')
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'),
          )
          ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
          ..addFont(
            rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'),
          ))
        .load();
  });

  testWidgets('tesis listesi mobil görsel inceleme', (tester) async {
    final boundary = GlobalKey();
    await _pump(
      tester,
      boundary,
      const VenuesScreen(),
    );
    expect(find.text('Halka açık kortlar'), findsOneWidget);
    expect(find.textContaining('Meram Spor Kompleksi'), findsNWidgets(2));
    expect(find.text('Saatleri gör'), findsNWidgets(2));
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/venues-list-mobile.png'),
    );
    final platformError = tester.takeException();
    expect(
      platformError == null || _isUnavailableAppLinks(platformError),
      isTrue,
    );
  });

  testWidgets('kort saat seçimi ve kesin sonuç görsel inceleme',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(tester, boundary, const CourtDetailScreen(court: _court));
    expect(find.text('Müsait saatler'), findsOneWidget);
    expect(find.text('Dolu'), findsWidgets);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/venue-court-slots.png'),
    );
    await tester.tap(find.text('Al'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saati al'));
    await tester.pumpAndSettle();
    expect(find.text('Saat ayrıldı'), findsOneWidget);
    expect(find.textContaining('09.11.2026 · 19:00'), findsOneWidget);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/venue-court-result.png'),
    );
  });

  testWidgets('halı saha isteği onay bekliyor sonucu verir', (tester) async {
    final boundary = GlobalKey();
    await _pump(
      tester,
      boundary,
      const TurfFieldDetailScreen(field: _field),
    );
    await tester.tap(find.text('Boş').first);
    await tester.pumpAndSettle();
    expect(find.text('Rezervasyon isteği gönder'), findsOneWidget);
    await tester.tap(find.text('Rezervasyon isteği gönder'));
    await tester.pumpAndSettle();
    expect(find.text('İstek gönderildi'), findsWidgets);
    expect(find.textContaining('Durum: Onay bekliyor'), findsOneWidget);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/venue-turf-result.png'),
    );
  });

  testWidgets('dar büyük yazı ve geniş koyu görünüm taşmaz', (tester) async {
    await _pump(
      tester,
      GlobalKey(),
      const VenuesScreen(),
      size: const Size(320, 568),
      textScale: 1.6,
    );
    var error = tester.takeException();
    expect(error == null || _isUnavailableAppLinks(error), isTrue);

    await _pump(
      tester,
      GlobalKey(),
      const TurfFieldDetailScreen(field: _field),
      size: const Size(1440, 900),
      textScale: 1.3,
      brightness: Brightness.dark,
    );
    error = tester.takeException();
    expect(error == null || _isUnavailableAppLinks(error), isTrue);
  });

  testWidgets('seçilen saat dolarsa kullanıcı başka saate yönlendirilir',
      (tester) async {
    await _pump(
      tester,
      GlobalKey(),
      const CourtDetailScreen(court: _court),
      courtService: _OccupiedCourts(),
    );
    await tester.tap(find.text('Al'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saati al'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('Bu saat az önce doldu'), findsOneWidget);
    expect(find.text('Müsait saatler'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  GlobalKey boundary,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  CourtService? courtService,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final baseTheme =
      brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
  final theme = baseTheme.copyWith(
    textTheme: baseTheme.textTheme.apply(fontFamily: 'Plus Jakarta Sans'),
    primaryTextTheme:
        baseTheme.primaryTextTheme.apply(fontFamily: 'Plus Jakarta Sans'),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            verificationTier: 'phone',
          ),
        ),
        courtsProvider(null).overrideWith((_) async => [_court, _secondCourt]),
        turfFieldsProvider(null).overrideWith((_) async => [_field]),
        courtTimelineProvider(_court.id).overrideWith(
          (_) async => [
            TimelineSlot(
              startsAt: _start,
              status: 'free',
              needed: 0,
              players: 0,
              mine: false,
            ),
            TimelineSlot(
              startsAt: _start.add(const Duration(hours: 1)),
              status: 'claimed',
              needed: 0,
              players: 2,
              mine: false,
              slotId: 'busy-slot',
              ownerName: 'Ayşe',
            ),
          ],
        ),
        turfOccupancyGridProvider(_field.id).overrideWith(
          (_) async => [
            TurfSlot(startsAt: _start, occupied: false),
            TurfSlot(
              startsAt: _start.add(const Duration(hours: 1)),
              occupied: true,
            ),
            TurfSlot(
              startsAt: _start.add(const Duration(days: 1)),
              occupied: false,
            ),
          ],
        ),
        courtServiceProvider.overrideWithValue(courtService ?? _Courts()),
        turfServiceProvider.overrideWithValue(_Turf()),
        featureEnabledProvider(FeatureFlags.courtWaitlist)
            .overrideWith((_) => false),
        featureEnabledProvider(FeatureFlags.turfDelegation)
            .overrideWith((_) => false),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          routes: {
            '/partner-ara': (_) => const Scaffold(),
            '/mesajlar': (_) => const Scaffold(),
          },
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(GlobalKey boundary, String path) async {
  final object = boundary.currentContext!.findRenderObject();
  final image = await (object! as RenderRepaintBoundary).toImage();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
}

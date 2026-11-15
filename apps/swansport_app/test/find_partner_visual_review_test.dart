import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/courts/presentation/find_partner_screen.dart';
import 'package:swansport_data/swansport_data.dart';

bool _isUnavailableAppLinks(Object? error) =>
    error is MissingPluginException &&
    error.message?.contains('com.llfbandit.app_links/events') == true;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('dolu partner lobisi mobil görsel inceleme', (tester) async {
    final boundary = GlobalKey();
    await _pumpLobby(tester, boundary: boundary);
    expect(find.textContaining('Ayşe'), findsOneWidget);
    expect(find.textContaining('Merkez Kortu'), findsOneWidget);
    expect(find.text('İstek gönderildi'), findsOneWidget);
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/partner-lobby-filled-current.png',
      ),
    );
    final platformError = tester.takeException();
    expect(
        platformError == null || _isUnavailableAppLinks(platformError), isTrue);
  });

  testWidgets('aktif partner araması mobil görsel inceleme', (tester) async {
    final boundary = GlobalKey();
    await _pumpLobby(
      tester,
      boundary: boundary,
      request: _activeRequest,
      inbox: const [],
    );
    expect(find.textContaining('Tenis'), findsWidgets);
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/partner-lobby-active-current.png',
      ),
    );
  });

  testWidgets('boş partner lobisi mobil görsel inceleme', (tester) async {
    final boundary = GlobalKey();
    await _pumpLobby(
      tester,
      boundary: boundary,
      slots: const [],
      publicRequests: const [],
      inbox: const [],
    );
    await tester.runAsync(
      () => _capture(
        boundary,
        'build/design-review/partner-lobby-empty-current.png',
      ),
    );
  });

  testWidgets('geniş koyu lobi ve büyük metin taşmaz', (tester) async {
    final boundary = GlobalKey();
    await _pumpLobby(
      tester,
      boundary: boundary,
      size: const Size(1440, 900),
      brightness: Brightness.dark,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Açık oyunlar'), findsOneWidget);
  });
}

Future<void> _pumpLobby(
  WidgetTester tester, {
  required GlobalKey boundary,
  List<OpenSlot>? slots,
  List<PublicPartnerRequest>? publicRequests,
  List<IncomingPartnerPing>? inbox,
  MyPartnerRequest? request,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(_verifiedAccess),
        courtSportCodesProvider.overrideWith(
          (_) async => const [
            CityRow(code: 'tennis', name: 'Tenis'),
            CityRow(code: 'basketball', name: 'Basketbol'),
          ],
        ),
        mySportInterestsProvider.overrideWith((_) async => {'tennis'}),
        myOpenPartnerRequestProvider.overrideWith((_) async => request),
        incomingPartnerPingsProvider.overrideWith((_) async => inbox ?? _inbox),
        openSlotsProvider(null).overrideWith((_) async => slots ?? _slots),
        publicPartnerRequestsProvider.overrideWith(
          (_) async => publicRequests ?? _publicRequests,
        ),
      ],
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const FindPartnerScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

const _verifiedAccess = SwanAccess(
  isPlatformAdmin: false,
  clubRole: null,
  coachLevel: 0,
  athleteKind: null,
  verificationTier: 'phone',
);

final _slots = [
  OpenSlot(
    slotId: 'slot-1',
    courtId: 'court-1',
    courtName: 'Merkez Kortu Çok Uzun Saha Adı',
    startsAt: DateTime.now().add(const Duration(hours: 3)),
    ownerId: 'owner-1',
    ownerName: 'Mert Demir',
    needed: 2,
    accepted: 1,
    requested: false,
    venue: 'Swan Spor Tesisi',
    cityName: 'İstanbul',
  ),
  OpenSlot(
    slotId: 'slot-2',
    courtId: 'court-2',
    courtName: 'Sahil Kortu',
    startsAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
    ownerId: 'owner-2',
    ownerName: 'Deniz Kaya',
    needed: 2,
    accepted: 0,
    requested: true,
    venue: 'Sahil Parkı',
    cityName: 'İstanbul',
  ),
];

final _inbox = [
  IncomingPartnerPing(
    requestId: 'request-1',
    sportCode: 'tennis',
    sportName: 'Tenis',
    requesterId: 'actor-1',
    requesterName: 'Ayşe Yılmaz',
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
  ),
];

final _publicRequests = [
  PublicPartnerRequest(
    id: 'public-1',
    sportCode: 'basketball',
    sportName: 'Basketbol',
    cityName: 'İstanbul',
    expiresAt: DateTime.now().add(const Duration(hours: 6)),
  ),
];

final _activeRequest = MyPartnerRequest(
  id: 'mine-1',
  sportCode: 'tennis',
  sportName: 'Tenis',
  status: 'open',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(hours: 8)),
);

Future<void> _capture(GlobalKey key, String path) async {
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}

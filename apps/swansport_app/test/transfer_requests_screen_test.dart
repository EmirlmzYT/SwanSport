import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/transfers/transfer_requests_screen.dart';

class FakeTransfers extends TransferRequestService {
  FakeTransfers() : super(Supabase.instance.client);
  bool fail = false;
  final actions = <(String, String)>[];
  @override
  Future<void> act(String id, String action) async {
    actions.add((id, action));
    if (fail) throw Exception('lost reply');
  }
}

TransferRequest row() => TransferRequest.fromMap({
      'id': 'r',
      'athlete_reference': '#A3F91C',
      'sport_code': 'tenis',
      'from_club': 'Kaynak Kulüp',
      'to_club': 'Hedef Kulüp',
      'reason': 'Yeni sezon planı',
      'status': 'pending',
      'consented': false,
      'accepted': true,
      'can_consent': true,
      'can_reject': true
    });
void main() {
  Future<void> mount(WidgetTester t, FakeTransfers s,
      {bool enabled = true, double scale = 1, bool dark = false}) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          authSessionProvider.overrideWith((_) => Stream.value(null)),
          swanAccessProvider.overrideWithValue(const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'parent',
              coachLevel: 0,
              athleteKind: null)),
          featureEnabledProvider(FeatureFlags.transferRequests)
              .overrideWithValue(enabled),
          transferRequestServiceProvider.overrideWithValue(s),
          transferRequestsProvider.overrideWith((_) async => [row()]),
          transferRequestOptionsProvider.overrideWith((_) async =>
              TransferRequestOptions.fromMap(
                  {'athletes': <dynamic>[], 'clubs': <dynamic>[]})),
        ],
        child: RepaintBoundary(
            key: const Key('transfer-preview'),
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? ThemeData.dark() : ThemeData.light(),
                builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const TransferRequestsScreen()))));
    await t.pumpAndSettle();
  }

  testWidgets('feature off blocks direct route', (t) async {
    final s = FakeTransfers();
    await mount(t, s, enabled: false);
    expect(find.textContaining('bu hesaba açık değil'), findsOneWidget);
    expect(find.text('Onay ver'), findsNothing);
    expect(s.actions, isEmpty);
  });
  testWidgets(
      'explicit consent and ambiguous retry reuse the same request/action',
      (t) async {
    final s = FakeTransfers()..fail = true;
    await mount(t, s);
    await t.tap(find.text('Onay ver'));
    await t.pumpAndSettle();
    expect(s.actions, isEmpty);
    await t.tap(find.text('Onayla'));
    await t.pumpAndSettle();
    expect(s.actions, [('r', 'consent')]);
    expect(find.text('Aynı işlemi tekrar dene'), findsOneWidget);
    s.fail = false;
    await t.tap(find.text('Aynı işlemi tekrar dene'));
    await t.pumpAndSettle();
    expect(s.actions, [('r', 'consent'), ('r', 'consent')]);
    expect(find.text('Aynı işlemi tekrar dene'), findsNothing);
  });
  testWidgets(
      'compact width and large text keep actions visible without overflow',
      (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await mount(t, FakeTransfers(), scale: 1.6);
    expect(t.takeException(), isNull);
    expect(find.text('Onay ver'), findsOneWidget);
  });
  if (const bool.fromEnvironment('CAPTURE_WORKFLOWS'))
    for (final dark in [false, true]) {
      testWidgets('capture transfer screen ${dark ? 'dark' : 'light'}',
          (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.runAsync(() async {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await (FontLoader('Roboto')
                ..addFont(rootBundle
                    .load('assets/fonts/PlusJakartaSans-Regular.ttf')))
              .load();
        });
        await mount(t, FakeTransfers(), dark: dark);
        await t.runAsync(() => GoogleFonts.pendingFonts());
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final render = t.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('transfer-preview')));
          final img = await render.toImage(pixelRatio: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
              '../../build/quick-access-verification/transfer-${dark ? 'dark' : 'light'}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      });
    }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/features/social/presentation/widgets/platform_notice.dart';
import 'package:swansport_app/features/social/presentation/feed_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/social/presentation/widgets/stitch_feed_widgets.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('broadcast is dismissible and changed content reappears', (tester) async {
    Widget banner(String message) => MaterialApp(home: Scaffold(body: PlatformBroadcastBanner(
      key: ValueKey(message), alert: {'severity': 'danger', 'title': 'Duyuru', 'message': message})));
    await tester.pumpWidget(banner('Birinci mesaj'));
    expect(find.text('Birinci mesaj'), findsOneWidget);
    await tester.tap(find.byTooltip('Duyuruyu kapat')); await tester.pump();
    expect(find.text('Birinci mesaj'), findsNothing);
    await tester.pumpWidget(banner('İkinci mesaj'));
    expect(find.text('İkinci mesaj'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('guest maintenance gates feed without private feed reads', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'maintenance': {'enabled': true, 'message': 'Planlı bakım'}})),
      feedProvider.overrideWith((_) async => throw StateError('must not read')),
      discoverProvider.overrideWith((_) async => throw StateError('must not read')),
    ], child: const MaterialApp(home: FeedScreen())));
    await tester.pump(); await tester.pump();
    expect(find.text('SwanSport Bakımda'), findsOneWidget);
    expect(find.text('Planlı bakım'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('maintenance retry works on narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: PlatformMaintenanceNotice(message: 'Planlı bakım', onRetry: () => retries++))));
    await tester.tap(find.text('Durumu yeniden kontrol et'));
    expect(retries, 1); expect(tester.takeException(), isNull);
  });
  testWidgets('platform administrator bypasses the feed maintenance view', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      swanAccessProvider.overrideWithValue(const SwanAccess(isPlatformAdmin: true, clubRole: null, coachLevel: 0, athleteKind: null)),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'maintenance': {'enabled': true, 'message': 'Bakım'}})),
      discoverProvider.overrideWith((_) async => []),
      announcementsProvider.overrideWith((_) async => []),
      newsProvider.overrideWith((_) async => []),
    ], child: const MaterialApp(home: FeedScreen())));
    await tester.pump(); await tester.pump();
    expect(find.text('SwanSport Bakımda'), findsNothing);
    await tester.tap(find.byTooltip('Akış seçimi'));
    await tester.pumpAndSettle();
    expect(find.text('Tümü (Keşfet)'), findsOneWidget);
    expect(find.text('Takip Ettiklerim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('feed header renders configured name and logo', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'branding': {
        'app_name': 'Özel Kulüp', 'logo_url': 'https://example.com/logo.png'}})),
    ], child: const MaterialApp(home: Scaffold(body: SizedBox(height: 56, child: StitchFeedTopBar())))));
    await tester.pumpAndSettle();
    expect(find.text('Özel Kulüp'), findsOneWidget);
    final network = find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage);
    expect((tester.widget<Image>(network).image as NetworkImage).url, 'https://example.com/logo.png');
    expect(tester.takeException(), isNull);
  });
  testWidgets('maintenance uses configured name, whitespace name falls back', (tester) async {
    Future<void> render(String name) async {
      await tester.pumpWidget(ProviderScope(key: ValueKey(name), overrides: [
        platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'branding': {'app_name': name}})),
      ], child: MaterialApp(home: PlatformMaintenanceNotice(message: 'Bakım', onRetry: () {}))));
      await tester.pumpAndSettle();
    }
    await render('Özel Kulüp'); expect(find.text('Özel Kulüp Bakımda'), findsOneWidget);
    await render('   '); expect(find.text('SwanSport Bakımda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

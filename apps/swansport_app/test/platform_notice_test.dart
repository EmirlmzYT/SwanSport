import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/features/social/presentation/widgets/platform_notice.dart';
import 'package:swansport_app/features/social/presentation/feed_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

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
    await tester.pumpWidget(MaterialApp(home: PlatformMaintenanceNotice(message: 'Planlı bakım', onRetry: () => retries++)));
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
    expect(find.text('Tümü (Keşfet)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

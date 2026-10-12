import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/app/shell/too_narrow_notice.dart';
import 'package:swansport_console/features/platform/mission_control_screen.dart';
import 'package:swansport_console/features/platform/diagnostics_screen.dart';

class _Service extends Fake implements PlatformMissionControlService {
  final writes = <String>[];
  @override
  Future<void> updatePlatformSetting(String key, Map<String, dynamic> value) async => writes.add(key);
}
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  void size(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
  }
  testWidgets('non-admin cannot start platform reads', (tester) async {
    size(tester, 1200);
    await tester.pumpWidget(ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(SwanAccess.none),
      platformConfigProvider.overrideWith((_) => throw StateError('must not read')),
    ], child: const MaterialApp(home: Scaffold(body: MissionControlScreen()))));
    expect(find.textContaining('yalnız platform yöneticilerine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow desktop guard precedes provider reads', (tester) async {
    size(tester, 899);
    await tester.pumpWidget(ProviderScope(overrides: [platformConfigProvider.overrideWith((_) => throw StateError('must not read'))],
      child: const MaterialApp(home: Scaffold(body: MissionControlScreen()))));
    expect(find.byType(TooNarrowNotice), findsOneWidget);
  });
  testWidgets('five tabs, validated branding and write contract', (tester) async {
    size(tester, 1200); final service = _Service();
    await tester.pumpWidget(ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(const SwanAccess(isPlatformAdmin: true, clubRole: null, coachLevel: 0, athleteKind: null)),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'branding': {'app_name': 'SwanSport'}})),
      platformPlansProvider.overrideWith((_) async => []),
      platformAuditLogsProvider.overrideWith((_) async => []),
      diagnosticOverviewProvider.overrideWith((_) async => {'open_issues': 2}),
      platformMissionControlServiceProvider.overrideWithValue(service),
    ], child: MaterialApp(theme: ConsoleTheme.dark(), home: const Scaffold(body: MissionControlScreen()))));
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(5));
    final name = find.widgetWithText(TextFormField, 'Uygulama Adı');
    await tester.enterText(name, '');
    await tester.tap(find.text('Kaydet').first); await tester.pump();
    expect(service.writes, isEmpty); expect(find.text('Bu alan gerekli'), findsOneWidget);
    await tester.enterText(name, 'SwanSport Yeni');
    await tester.tap(find.text('Finans & Komisyonlar')); await tester.pumpAndSettle();
    await tester.tap(find.text('Marka & Görünüm')); await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(name).controller!.text, 'SwanSport Yeni');
    await tester.tap(find.text('Kaydet').first); await tester.pumpAndSettle();
    expect(service.writes, ['branding']);
    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

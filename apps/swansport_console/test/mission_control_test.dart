import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/app/shell/too_narrow_notice.dart';
import 'package:swansport_console/features/platform/mission_control_screen.dart';
import 'package:swansport_console/features/platform/diagnostics_screen.dart';
import 'package:swansport_console/app/media/image_picker.dart';

class _Service extends Fake implements PlatformMissionControlService {
  final writes = <String>[];
  int uploads = 0;
  @override
  Future<void> updatePlatformSetting(String key, Map<String, dynamic> value) async => writes.add(key);
  @override
  Future<String> uploadBrandLogo({required Uint8List bytes, required String name, required String mimeType}) async {
    uploads++;
    return 'https://example.com/uploaded-logo.png';
  }
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
    await tester.ensureVisible(find.text('Kaydet').first);
    await tester.tap(find.text('Kaydet').first); await tester.pump();
    expect(service.writes, isEmpty); expect(find.text('Bu alan gerekli'), findsOneWidget);
    await tester.enterText(name, 'SwanSport Yeni');
    await tester.tap(find.text('Finans & Komisyonlar')); await tester.pumpAndSettle();
    await tester.tap(find.text('Marka & Görünüm')); await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(name).controller!.text, 'SwanSport Yeni');
    await tester.ensureVisible(find.text('Kaydet').first);
    await tester.tap(find.text('Kaydet').first); await tester.pumpAndSettle();
    expect(service.writes, ['branding']);
    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('VM image picker safely cancels without browser libraries', () async {
    expect(await pickImageFile(), isNull);
  });
  testWidgets('existing logo renders and removal clears URL draft', (tester) async {
    size(tester, 1200);
    await tester.pumpWidget(ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(const SwanAccess(isPlatformAdmin: true, clubRole: null, coachLevel: 0, athleteKind: null)),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'branding': {
        'app_name': 'SwanSport', 'logo_url': 'https://example.com/logo.png'}})),
      platformPlansProvider.overrideWith((_) async => []),
      platformAuditLogsProvider.overrideWith((_) async => []),
      diagnosticOverviewProvider.overrideWith((_) async => {}),
    ], child: MaterialApp(theme: ConsoleTheme.dark(), home: const Scaffold(body: MissionControlScreen()))));
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('brand-logo-preview'));
    expect(tester.getSize(preview), const Size(ConsoleDensity.logoPreviewSize, ConsoleDensity.logoPreviewSize));
    final image = tester.widget<Image>(find.descendant(of: preview, matching: find.byType(Image)));
    expect((image.image as NetworkImage).url, 'https://example.com/logo.png');
    await tester.tap(find.text('Logoyu Kaldır')); await tester.pump();
    expect(find.text('Logoyu Kaldır'), findsNothing);
    expect(find.descendant(of: preview, matching: find.byType(Image)), findsNothing);
    await tester.tap(find.text('Manuel Logo URL (opsiyonel)')); await tester.pumpAndSettle();
    final url = tester.widget<TextFormField>(find.byKey(const ValueKey('brand-logo-url')));
    expect(url.controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelled logo selection leaves form editable', (tester) async {
    size(tester, 1200);
    await tester.pumpWidget(ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(const SwanAccess(isPlatformAdmin: true, clubRole: null, coachLevel: 0, athleteKind: null)),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'branding': {'app_name': 'SwanSport'}})),
      missionLogoPickerProvider.overrideWithValue(() async => null),
      platformPlansProvider.overrideWith((_) async => []),
      platformAuditLogsProvider.overrideWith((_) async => []),
      diagnosticOverviewProvider.overrideWith((_) async => {}),
    ], child: MaterialApp(theme: ConsoleTheme.dark(), home: const Scaffold(body: MissionControlScreen()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logo Yükle')); await tester.pumpAndSettle();
    expect(find.text('Logo yükleniyor…'), findsNothing);
    expect(find.text('Logoyu Kaldır'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('selected logo is uploaded and previewed without publishing branding', (tester) async {
    size(tester, 1200); final service = _Service();
    await tester.pumpWidget(ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(const SwanAccess(isPlatformAdmin: true, clubRole: null, coachLevel: 0, athleteKind: null)),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({'branding': {'app_name': 'SwanSport'}})),
      missionLogoPickerProvider.overrideWithValue(() async => PickedImageFile(bytes: Uint8List.fromList([1]), name: 'logo.png', mimeType: 'image/png')),
      platformMissionControlServiceProvider.overrideWithValue(service),
      platformPlansProvider.overrideWith((_) async => []),
      platformAuditLogsProvider.overrideWith((_) async => []),
      diagnosticOverviewProvider.overrideWith((_) async => {}),
    ], child: MaterialApp(theme: ConsoleTheme.dark(), home: const Scaffold(body: MissionControlScreen()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logo Yükle')); await tester.pumpAndSettle();
    expect(service.uploads, 1); expect(service.writes, isEmpty);
    expect(find.text('Logoyu Kaldır'), findsOneWidget);
    final image = tester.widget<Image>(find.descendant(of: find.byKey(const ValueKey('brand-logo-preview')), matching: find.byType(Image)));
    expect((image.image as NetworkImage).url, 'https://example.com/uploaded-logo.png');
    expect(tester.takeException(), isNull);
  });
}

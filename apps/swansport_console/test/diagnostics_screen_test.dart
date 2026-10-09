import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/modules/module_registry.dart';
import 'package:swansport_console/features/platform/diagnostics_screen.dart';
import 'package:swansport_data/swansport_data.dart';

class DiagnosticServiceFake extends Fake implements DiagnosticsService {
  final queries = <DiagnosticQuery>[];
  final statuses = <String>[];
  final fixes = <(String, String, String)>[];
  @override
  Future<List<Map<String, dynamic>>> issues(
      {String? status,
      String? release,
      String? platform,
      String? screen,
      int offset = 0}) async {
    queries.add((
      status: status,
      release: release,
      platform: platform,
      screen: screen,
      offset: offset
    ));
    return [
      {
        'id': 'issue-1',
        'operation': 'rpc:create_finance_adjustment',
        'code': 'http_400',
        'state': 'new',
        'occurrence_count': 3,
        'session_count': 2,
        'release': '0.5.1+16',
        'platform': 'android',
        'screen': '/destek',
        'total_count': 101
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> overview() async => {
        'open_issues': 1,
        'errors_24h': 3,
        'sessions_24h': 2,
        'alerts': [],
        'flows': [],
        'consistency': [
          {'code': 'invalid_financial_amount', 'count': 1},
          {'code': 'unmatched_approved_adjustment', 'count': 2}
        ]
      };
  @override
  Future<Map<String, dynamic>> detail(String issue) async =>
      {'events': [], 'server_events': []};
  @override
  Future<String> declareFix(
      String issue, String release, String platform) async {
    fixes.add((issue, release, platform));
    return 'fix';
  }

  @override
  Future<void> setStatus(String issue, String status) async {
    statuses.add(status);
  }
}

void main() {
  const admin = SwanAccess(
      isPlatformAdmin: true,
      clubRole: 'member',
      coachLevel: 0,
      athleteKind: null);
  const coach = SwanAccess(
      isPlatformAdmin: false,
      clubRole: 'coach',
      coachLevel: 4,
      athleteKind: null);
  late DiagnosticServiceFake service;
  late DiagnosticsRecorder recorder;
  setUp(() {
    service = DiagnosticServiceFake();
    recorder = DiagnosticsRecorder();
  });
  tearDown(() => recorder.dispose());
  Future<void> mount(WidgetTester tester, SwanAccess access) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(access),
      isSupabaseEnabledProvider.overrideWithValue(true),
      diagnosticsServiceProvider.overrideWithValue(service),
      diagnosticsProvider.overrideWithValue(recorder),
    ], child: const MaterialApp(home: Scaffold(body: DiagnosticsScreen()))));
    await tester.pumpAndSettle();
  }

  testWidgets('platform restriction blocks both navigation and data requests',
      (tester) async {
    final module = kConsoleModules.singleWhere((m) => m.id == 'diagnostics');
    expect(module.visibleTo(coach), false);
    expect(module.visibleTo(admin), true);
    await mount(tester, coach);
    expect(find.text('Bu ekran yalnızca platform yöneticisine açıktır.'),
        findsOneWidget);
    expect(service.queries, isEmpty);
  });
  testWidgets('filters reset server pagination and preserve the chosen release',
      (tester) async {
    await mount(tester, admin);
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(service.queries.last.offset, 50);
    await tester.enterText(find.widgetWithText(TextField, 'Sürüm'), '0.5.2+17');
    await tester.tap(find.text('Filtrele'));
    await tester.pumpAndSettle();
    expect(service.queries.last.offset, 0);
    expect(service.queries.last.release, '0.5.2+17');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'fix declaration requires release and platform and refreshes the list',
      (tester) async {
    await mount(tester, admin);
    await tester.tap(find.text('rpc:create_finance_adjustment · http_400'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Düzeltildi'));
    final calls = service.queries.length;
    await tester.tap(find.widgetWithText(FilledButton, 'Düzeltildi'));
    await tester.pumpAndSettle();
    expect(service.fixes, isEmpty);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Düzeltme sürümü'), '0.5.2+17');
    await tester.tap(find.widgetWithText(
        DropdownButtonFormField<String>, 'Düzeltme platformu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('android').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Düzeltmeyi bildir'));
    await tester.pumpAndSettle();
    expect(service.fixes, [('issue-1', '0.5.2+17', 'android')]);
    expect(service.statuses, isEmpty);
    expect(service.queries.length, greaterThan(calls));
  });
}

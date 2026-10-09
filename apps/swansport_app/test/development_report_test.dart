import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/features/reports/presentation/screens/development_report_screen.dart';
import 'package:swansport_app/features/reports/presentation/widgets/development_report_export.dart';
import 'package:swansport_data/swansport_data.dart';

DevelopmentReport report({String fingerprint = 'old', int present = 0}) =>
    DevelopmentReport(
      athlete: const ReportAthlete(
        id: 'a',
        name: 'Ada Gizli',
        clubName: 'Özel Kulüp',
      ),
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
      generatedAt: DateTime.utc(2026, 10, 7),
      fingerprint: fingerprint,
      attendance: ReportAttendance(
        present: present,
        late: 0,
        absent: 0,
        excused: 0,
        unlinked: 0,
        rate: present == 0 ? null : 100,
      ),
      metrics: [],
      goals: [],
    );
final request =
    (athleteId: 'a', from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30));

class Service extends Fake implements DevelopmentReportService {
  DevelopmentReport current = report();
  int loads = 0;
  Object? failure;
  Completer<DevelopmentReport>? held;
  final queries = <({String query, int offset})>[];
  @override
  Future<DevelopmentReport> load(DevelopmentReportRequest request) async {
    loads++;
    if (failure != null) throw failure!;
    return held == null ? current : held!.future;
  }

  @override
  Future<ReportAthletePage> athletes({
    String query = '',
    int offset = 0,
  }) async {
    queries.add((query: query, offset: offset));
    if (failure != null) throw failure!;
    return ReportAthletePage(
      [
        ReportAthlete(
          id: offset == 0 ? 'a' : 'b',
          name: offset == 0 ? 'Ada Gizli' : 'Ece',
        ),
      ],
      offset == 0,
    );
  }
}

void main() {
  late Service service;
  late List<String> copies;
  setUp(() {
    service = Service();
    copies = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copies.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  Future<void> mount(
    WidgetTester t, {
    bool enabled = true,
    bool dialog = false,
    String? athleteId = 'a',
    Stream<Session?>? sessions,
  }) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          featureEnabledProvider(FeatureFlags.developmentReport)
              .overrideWith((_) => enabled),
          isSupabaseEnabledProvider.overrideWithValue(true),
          authSessionProvider
              .overrideWith((_) => sessions ?? Stream.value(null)),
          developmentReportServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: dialog
              ? Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => DevelopmentReportExport(
                          request: request,
                          report: report(),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                )
              : DevelopmentReportScreen(athleteId: athleteId),
        ),
      ),
    );
    await t.pumpAndSettle();
    if (dialog) {
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
    }
  }

  testWidgets('closed feature blocks direct route without service reads',
      (t) async {
    await mount(t, enabled: false);
    expect(
      find.text('Bu özellik şu anda hesabına açık değil.'),
      findsOneWidget,
    );
    expect(service.loads, 0);
    expect(service.queries, isEmpty);
  });
  testWidgets(
      'empty report explicitly retains unknown attendance on narrow screen',
      (t) async {
    await mount(t);
    expect(find.text('Oran hesaplanamıyor'), findsOneWidget);
    expect(find.text('Devam oranı: %0'), findsNothing);
    expect(find.text('Bu dönemde ölçüm kaydı yok.'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('search and pagination send server query and reset offset',
      (t) async {
    await mount(t, athleteId: null);
    await t.tap(find.text('Sonraki'));
    await t.pumpAndSettle();
    expect(service.queries.last, (query: '', offset: 40));
    expect(find.text('Ece'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Işık');
    await t.tap(find.text('Ara'));
    await t.pumpAndSettle();
    expect(service.queries.last, (query: 'Işık', offset: 0));
    await t.tap(find.text('Ada Gizli'));
    await t.pumpAndSettle();
    expect(service.loads, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('failed report exposes retry and success replaces error',
      (t) async {
    service.failure = StateError('denied');
    await mount(t);
    expect(find.text('Rapor yüklenemedi veya erişimin yok.'), findsOneWidget);
    final beforeRetry = service.loads;
    service.failure = null;
    await t.tap(find.text('Tekrar dene'));
    await t.pumpAndSettle();
    expect(find.text('Oran hesaplanamıyor'), findsOneWidget);
    expect(service.loads, beforeRetry + 1);
  });
  testWidgets('preview hides identity and copy performs a fresh server read',
      (t) async {
    await mount(t, dialog: true);
    expect(find.textContaining('Sporcu: Ada Gizli'), findsNothing);
    await t.tap(find.text('Metni kopyala'));
    await t.pumpAndSettle();
    expect(service.loads, 1);
    expect(copies, hasLength(1));
    expect(copies.single, isNot(contains('Ada Gizli')));
    expect(find.byType(AlertDialog), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('identity only included after explicit checkbox selection',
      (t) async {
    await mount(t, dialog: true);
    await t.tap(find.byType(Checkbox));
    await t.pumpAndSettle();
    await t.tap(find.text('Metni kopyala'));
    await t.pumpAndSettle();
    expect(copies.single, contains('Ada Gizli · Özel Kulüp'));
  });
  testWidgets('revoked permission or offline failure never writes clipboard',
      (t) async {
    await mount(t, dialog: true);
    service.failure = StateError('revoked');
    await t.tap(find.text('Metni kopyala'));
    await t.pumpAndSettle();
    expect(copies, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Metin kopyalanamadı.'), findsOneWidget);
  });
  testWidgets('changed snapshot updates preview and needs second copy action',
      (t) async {
    await mount(t, dialog: true);
    service.current = report(fingerprint: 'changed', present: 3);
    await t.tap(find.text('Metni kopyala'));
    await t.pumpAndSettle();
    expect(copies, isEmpty);
    expect(find.textContaining('Veri değişti.'), findsOneWidget);
    expect(find.textContaining('Katıldı: 3'), findsOneWidget);
    await t.tap(find.text('Metni kopyala'));
    await t.pumpAndSettle();
    expect(service.loads, 2);
    expect(copies.single, contains('Katıldı: 3'));
  });
  testWidgets('pending reauthorization prevents double copy', (t) async {
    await mount(t, dialog: true);
    service.held = Completer<DevelopmentReport>();
    await t.tap(find.text('Metni kopyala'));
    await t.pump();
    await t.tap(find.text('Metni kopyala'));
    await t.pump();
    expect(service.loads, 1);
    expect(copies, isEmpty);
    service.held!.complete(report());
    await t.pumpAndSettle();
    expect(copies, hasLength(1));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'logout during reauthorization closes preview and blocks late copy',
      (t) async {
    final session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: const User(
        id: 'user',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-07T00:00:00Z',
      ),
    );
    final updates = StreamController<Session?>();
    Stream<Session?> sessions() async* {
      yield session;
      yield* updates.stream;
    }

    addTearDown(updates.close);
    await mount(t, dialog: true, sessions: sessions());
    service.held = Completer<DevelopmentReport>();
    await t.tap(find.text('Metni kopyala'));
    await t.pump();
    updates.add(null);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    service.held!.complete(report());
    await t.pumpAndSettle();
    expect(copies, isEmpty);
    expect(t.takeException(), isNull);
  });
}

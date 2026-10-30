import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  final now = DateTime(2026, 10, 26);

  testWidgets('attendance flag gates providers', (tester) async {
    await _pumpLive(
      tester,
      flags: const FeatureFlags.none(),
      events: () async => throw StateError('must not load'),
    );
    expect(
      find.text('Yoklama operasyonları şu anda kullanıma kapalı.'),
      findsOneWidget,
    );
    expect(find.textContaining('must not load'), findsNothing);
  });

  testWidgets('authorized attendance state marks a roster row', (tester) async {
    await _pumpLive(tester, now: now);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Sunucuya kaydet (0)'), findsOneWidget);
    await tester.tap(find.text('Var'));
    await tester.pump();
    expect(find.text('Sunucuya kaydet (1)'), findsOneWidget);
  });

  testWidgets('online save preserves version and uncertain retry operation id',
      (tester) async {
    final chrome = _Chrome();
    final ids = <String>[];
    var calls = 0;
    List<Map<String, dynamic>>? sent;
    await _pumpLive(
      tester,
      now: now,
      operationId: () => 'stable-operation',
      chrome: chrome,
      save: ({required eventId, required opId, required marks}) async {
        ids.add(opId);
        sent = marks;
        if (calls++ == 0) throw TimeoutException('PRIVATE DETAIL');
        return const AttendanceOpResult(
          applied: 1,
          conflicts: [],
          replayed: true,
        );
      },
    );
    await tester.tap(find.text('Var'));
    await tester.pump();
    await tester.tap(find.text('Sunucuya kaydet (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PRIVATE DETAIL'), findsNothing);
    expect(find.text('Aynı işlemi tekrar dene'), findsOneWidget);
    expect(chrome.messages, hasLength(1));
    expect(chrome.messages.single.$2, ProFeatureMessageTone.warning);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Yok'))
          .onSelected,
      isNull,
    );
    await tester.tap(find.text('Aynı işlemi tekrar dene'));
    await tester.pumpAndSettle();
    expect(ids, ['stable-operation', 'stable-operation']);
    expect(sent!.single['version'], 3);
    expect(find.text('Yoklama sunucuda doğrulandı.'), findsOneWidget);
  });

  testWidgets('optimistic conflict remains explicit and dirty', (tester) async {
    final container = await _pumpLive(
      tester,
      now: now,
      save: ({required eventId, required opId, required marks}) async =>
          const AttendanceOpResult(
        applied: 0,
        conflicts: [
          AttendanceConflict(
            athleteId: 'athlete-1',
            reason: 'version_mismatch',
            sentStatus: 'present',
            currentStatus: 'absent',
          ),
        ],
        replayed: false,
      ),
    );
    await tester.tap(find.text('Var'));
    await tester.pump();
    await tester.tap(find.text('Sunucuya kaydet (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sunucuda Yok'), findsOneWidget);
    expect(container.read(proDirtyStateCoordinatorProvider).isDirty, isTrue);
  });

  testWidgets('dirty back transition asks and respects cancellation',
      (tester) async {
    final chrome = _Chrome(confirmResult: false);
    await _pumpLive(tester, now: now, chrome: chrome);
    await tester.tap(find.text('Var'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(chrome.confirmCalls, 1);
    expect(find.text('Ada'), findsOneWidget);

    chrome.confirmResult = true;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(chrome.confirmCalls, 2);
  });

  testWidgets('history has loading, safe error, empty and filters',
      (tester) async {
    final pending = Completer<List<AttendanceStat>>();
    await _pumpHistory(tester, summary: () => pending.future, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _pumpHistory(
      tester,
      summary: () async => throw StateError('PRIVATE DETAIL'),
    );
    expect(find.textContaining('PRIVATE DETAIL'), findsNothing);
    expect(find.textContaining('Gönderilen bilgiler'), findsOneWidget);

    await _pumpHistory(tester, summary: () async => const []);
    expect(find.text('Kayıt bulunamadı.'), findsOneWidget);

    await _pumpHistory(
      tester,
      summary: () async => const [
        AttendanceStat(
          athleteId: 'high',
          name: 'Ada Yılmaz',
          present: 9,
          absent: 1,
          total: 10,
          rate: 90,
        ),
        AttendanceStat(
          athleteId: 'risk',
          name: 'Ece Kaya',
          present: 5,
          absent: 5,
          total: 10,
          rate: 50,
        ),
      ],
    );
    await tester.tap(find.text('Riskli (<%70)'));
    await tester.pump();
    expect(find.text('Ece Kaya'), findsOneWidget);
    expect(find.text('Ada Yılmaz'), findsNothing);
  });

  testWidgets('attendance remains usable at 320px and 2x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpLive(tester, now: now, textScale: 2);
    expect(find.text('Ada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpLive(
  WidgetTester tester, {
  DateTime? now,
  FeatureFlags flags = const FeatureFlags({
    FeatureFlags.attendanceOperations,
  }),
  Future<List<EventRow>> Function()? events,
  AttendanceSaveCommand? save,
  String Function()? operationId,
  _Chrome? chrome,
  double textScale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      featureFlagsProvider.overrideWith((ref) async => flags),
      activeClubProvider.overrideWith(
        (ref) async =>
            const ClubRef(id: 'club-1', name: 'Kulüp', role: 'coach'),
      ),
      eventsProvider.overrideWith(
        (ref) => (events ??
            () async => [
                  EventRow(
                    id: 'event-1',
                    title: 'Antrenman',
                    place: null,
                    kind: 'training',
                    startsAt: now ?? DateTime(2026, 10, 26),
                  ),
                ])(),
      ),
      versionedRosterProvider('event-1').overrideWith(
        (ref) async => const [
          RosterEntry(
            athleteId: 'athlete-1',
            fullName: 'Ada',
            rsvp: 'attending',
            version: 3,
          ),
        ],
      ),
      attendanceQueueProvider.overrideWith((ref) async => null),
      attendanceLocalDataProvider.overrideWith(
        (ref) => Stream.value(const {'cache': [], 'drafts': [], 'ops': []}),
      ),
      attendanceSaveCommandProvider.overrideWithValue(
        save ??
            ({required eventId, required opId, required marks}) async =>
                AttendanceOpResult(
                  applied: marks.length,
                  conflicts: const [],
                  replayed: false,
                ),
      ),
      if (operationId != null)
        attendanceOperationIdProvider.overrideWithValue(operationId),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: ProFeatureHostScope(
            navigator: _Navigator(),
            chrome: chrome ?? _Chrome(),
            theme: ProFeatureThemeData.light,
            child: const SharedLiveAttendanceScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _pumpHistory(
  WidgetTester tester, {
  required Future<List<AttendanceStat>> Function() summary,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.attendanceOperations,
          }),
        ),
        attendanceSummaryProvider.overrideWith((ref) => summary()),
      ],
      child: MaterialApp(
        home: ProFeatureHostScope(
          navigator: _Navigator(),
          chrome: _Chrome(),
          theme: ProFeatureThemeData.light,
          child: const SharedAttendanceHistoryScreen(),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

final class _Navigator extends ProFeatureNavigatorBase {
  @override
  void openAttendance() {}
  @override
  void openAttendanceHistory() {}
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openTeams() {}
  @override
  void openTrainingBuilder() {}
  @override
  void openTrainingList() {}
  @override
  void openTrainingProtocols() {}
  @override
  void openTrainingResult({String? sessionId}) {}
  @override
  void openTrainingSession({String? sessionId}) {}
}

final class _Chrome implements ProFeatureChrome {
  _Chrome({this.confirmResult = true});

  bool confirmResult;
  int confirmCalls = 0;
  final messages = <(String, ProFeatureMessageTone)>[];

  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: body,
      );

  @override
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) async {
    confirmCalls++;
    return confirmResult;
  }

  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {
    messages.add((message, tone));
  }
}

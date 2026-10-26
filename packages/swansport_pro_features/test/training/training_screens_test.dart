import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

const _config = TrainingProtocolConfig(
  setCount: 3,
  unitsPerSet: 6,
  prepSeconds: 10,
  shootSeconds: 120,
  collectSeconds: 60,
  restSeconds: 0,
  maxUnitScore: 10,
  entryMode: ScoreEntryMode.flexible,
  mode: TrainingMode.technique,
  archetype: TrainingArchetype.targetScore,
);

void main() {
  testWidgets('training flag gates the shared entry', (tester) async {
    await _pump(
      tester,
      flags: const FeatureFlags.none(),
      child: const SharedTrainingListScreen(),
    );
    expect(
      find.text('Antrenman operasyonları şu anda kullanıma kapalı.'),
      findsOneWidget,
    );
  });

  testWidgets('protocol list starts a club session through typed navigation',
      (tester) async {
    final commands = _Commands();
    final navigator = _Navigator();
    await _pump(
      tester,
      commands: commands,
      navigator: navigator,
      protocols: const [
        TrainingProtocol(
          id: 'protocol-1',
          name: 'Hedef Çalışması',
          sportCode: 'archery',
          version: 1,
          config: _config,
        ),
      ],
      child: const SharedProtocolListScreen(),
    );
    await tester.ensureVisible(find.text('Başlat'));
    await tester.tap(find.text('Başlat'));
    await tester.pumpAndSettle();
    expect(commands.calls, contains('start:club-1:protocol-1'));
    expect(navigator.sessionId, 'session-new');
  });

  testWidgets('builder validates, tracks dirty state and creates protocol',
      (tester) async {
    final commands = _Commands();
    final container = await _pump(
      tester,
      commands: commands,
      child: const SharedWorkoutBuilderScreen(),
    );
    await tester.enterText(find.byKey(const Key('training-name')), 'Şut');
    await tester.enterText(find.byKey(const Key('training-sport')), 'football');
    expect(container.read(proDirtyStateCoordinatorProvider).isDirty, isTrue);
    await tester.tap(find.byKey(const Key('training-builder-save')));
    await tester.pumpAndSettle();
    expect(commands.calls, contains('create:club-1:football:Şut'));
  });

  testWidgets('live session submits athlete score', (tester) async {
    final commands = _Commands();
    await _pump(
      tester,
      commands: commands,
      access: const SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 0,
        athleteKind: 'licensed',
      ),
      session: const TrainingSession(
        id: 'session-1',
        clubId: 'club-1',
        kind: 'personal',
        status: 'live',
        phase: SessionPhase.shoot,
        currentSet: 1,
        setCount: 3,
        rhythm: SessionRhythm.shared,
        protocolName: 'Bireysel',
      ),
      child: const SharedTrainingSessionScreen(sessionId: 'session-1'),
    );
    await tester.enterText(find.byKey(const Key('training-score')), '42');
    await tester.tap(find.text('Seti kaydet'));
    await tester.pumpAndSettle();
    expect(commands.calls, contains('score:session-1:1:42'));
  });

  testWidgets('result review locks the session', (tester) async {
    final commands = _Commands();
    await _pump(
      tester,
      commands: commands,
      overview: const SessionOverview(
        joinedCount: 2,
        completedCount: 2,
        noScoreCount: 0,
        awaitingLock: 2,
        unitsRecorded: 12,
        unitsExpected: 12,
        protocolName: 'Takım',
        protocolVersion: 1,
        setCount: 3,
        status: 'review',
      ),
      child: const SharedSessionResultScreen(sessionId: 'session-1'),
    );
    await tester.tap(find.text('Onayla ve kilitle'));
    await tester.pumpAndSettle();
    expect(commands.calls, contains('lock:session-1'));
  });

  testWidgets('safe errors and 320px 2x text remain usable', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      textScale: 2,
      protocolsError: StateError('PRIVATE BACKEND DETAIL'),
      child: const SharedProtocolListScreen(),
    );
    expect(find.textContaining('PRIVATE BACKEND DETAIL'), findsNothing);
    expect(find.textContaining('Gönderilen bilgiler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Widget child,
  FeatureFlags flags = const FeatureFlags({
    FeatureFlags.sportTrainingSessions,
  }),
  SwanAccess access = const SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'coach',
    coachLevel: 1,
    athleteKind: null,
  ),
  List<TrainingProtocol> protocols = const [],
  Object? protocolsError,
  TrainingSession? session,
  SessionOverview? overview,
  TrainingOperationCommands? commands,
  _Navigator? navigator,
  double textScale = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      featureFlagsProvider.overrideWith((ref) async => flags),
      activeClubProvider.overrideWith(
        (ref) async => const ClubRef(
          id: 'club-1',
          name: 'Kulüp',
          role: 'coach',
        ),
      ),
      swanAccessProvider.overrideWithValue(access),
      trainingProtocolsProvider.overrideWith((ref) async {
        if (protocolsError != null) throw protocolsError;
        return protocols;
      }),
      myLiveSessionProvider.overrideWith((ref) async => null),
      myTrainingHistoryProvider.overrideWith((ref) async => const []),
      trainingSessionProvider('session-1').overrideWith((ref) async => session),
      sessionOverviewProvider('session-1')
          .overrideWith((ref) async => overview),
      sessionSummaryProvider('session-1').overrideWith((ref) async => const []),
      trainingOperationCommandsProvider.overrideWithValue(
        commands ?? _Commands(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: ProFeatureHostScope(
          navigator: navigator ?? _Navigator(),
          chrome: const _Chrome(),
          theme: ProFeatureThemeData.light,
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

final class _Commands implements TrainingOperationCommands {
  final calls = <String>[];
  @override
  Future<void> advance(String sessionId) async =>
      calls.add('advance:$sessionId');
  @override
  Future<String> createProtocol({
    required String clubId,
    required String sportCode,
    required String name,
    required TrainingProtocolConfig config,
  }) async {
    calls.add('create:$clubId:$sportCode:$name');
    return 'protocol-new';
  }

  @override
  Future<String> join(String code) async => 'session-joined';
  @override
  Future<int> lock(String sessionId) async {
    calls.add('lock:$sessionId');
    return 1;
  }

  @override
  Future<void> pause(String sessionId, bool paused) async =>
      calls.add('pause:$sessionId:$paused');
  @override
  Future<({String id, String joinCode})> startClub({
    required String clubId,
    required String protocolId,
  }) async {
    calls.add('start:$clubId:$protocolId');
    return (id: 'session-new', joinCode: 'ABC123');
  }

  @override
  Future<String> startPersonal({
    required String protocolId,
    String? clubId,
  }) async =>
      'session-personal';
  @override
  Future<void> submitSet({
    required String sessionId,
    required int setNo,
    required num total,
  }) async =>
      calls.add('score:$sessionId:$setNo:$total');
}

final class _Navigator extends ProFeatureNavigatorBase {
  String? sessionId;
  @override
  void openTrainingSession({String? sessionId}) => this.sessionId = sessionId;
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
}

final class _Chrome implements ProFeatureChrome {
  const _Chrome();
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
  }) async =>
      true;
  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {}
}

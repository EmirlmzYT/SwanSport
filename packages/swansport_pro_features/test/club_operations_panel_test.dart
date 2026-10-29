import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('shows explicit no-active-club state', (tester) async {
    await _pump(tester, club: null);
    expect(find.text('Aktif kulüp seçilmedi'), findsOneWidget);
    expect(find.byType(ClubOperationCard), findsNothing);
  });

  testWidgets('shows explicit no-operation-authority state', (tester) async {
    await _pump(
      tester,
      access: const SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 3,
        athleteKind: null,
      ),
    );
    expect(find.text('Kulüp operasyon yetkisi gerekli'), findsOneWidget);
    expect(find.byType(ClubOperationCard), findsNothing);
  });

  testWidgets('renders real provider counts and states for enabled cards',
      (tester) async {
    final navigator = _Navigator();
    await _pump(tester, navigator: navigator);

    expect(find.text('2 takım'), findsOneWidget);
    expect(find.text('8 aktif / 11 toplam'), findsOneWidget);
    expect(find.text('2 / 3 antrenmanda yoklama var'), findsOneWidget);
    expect(find.text('4 sporcu için devam kaydı'), findsOneWidget);
    expect(find.text('3 kullanılabilir şablon'), findsOneWidget);
    expect(find.text('Canlı: Sabah Kuvvet'), findsOneWidget);

    await tester.tap(find.text('Takımlar'));
    await tester.tap(find.text('Sporcu Kadrosu'));
    await tester.tap(find.text('Canlı Yoklama'));
    await tester.tap(find.text('Devam Geçmişi'));
    await tester.tap(find.text('Antrenman Şablonları'));
    await tester.tap(find.text('Antrenman Oturumu'));

    expect(
      navigator.calls,
      [
        'teams',
        'teams',
        'attendance',
        'attendance-history',
        'training-protocols',
        'training-session:session-1',
      ],
    );
  });

  testWidgets('no operation cards render without their rollout flags',
      (tester) async {
    await _pump(
      tester,
      flags: const FeatureFlags({FeatureFlags.coachWorkspace}),
    );
    expect(find.byType(ClubOperationCard), findsNothing);
    expect(
      find.text('Henüz açılmış bir operasyon modülü yok.'),
      findsOneWidget,
    );
  });

  testWidgets('team flag opens only team and roster cards', (tester) async {
    await _pump(
      tester,
      flags: const FeatureFlags({
        FeatureFlags.coachWorkspace,
        FeatureFlags.teamHub,
      }),
    );
    expect(find.text('Takımlar'), findsOneWidget);
    expect(find.text('Sporcu Kadrosu'), findsOneWidget);
    expect(find.text('Canlı Yoklama'), findsNothing);
    expect(find.text('Antrenman Şablonları'), findsNothing);
  });

  testWidgets('coach workspace flag gates the whole operation panel',
      (tester) async {
    await _pump(
      tester,
      flags: const FeatureFlags({
        FeatureFlags.teamHub,
        FeatureFlags.attendanceOperations,
        FeatureFlags.sportTrainingSessions,
      }),
    );
    expect(find.text('Operasyonlar kademeli yayında'), findsOneWidget);
    expect(find.byType(ClubOperationCard), findsNothing);
  });

  testWidgets('320px width and 2x text remain usable', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Kulüp Operasyonları'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  ClubRef? club = const ClubRef(
    id: 'club-1',
    name: 'Kulüp',
    role: 'club_admin',
  ),
  SwanAccess access = const SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'club_admin',
    coachLevel: 0,
    athleteKind: null,
  ),
  FeatureFlags flags = const FeatureFlags({
    FeatureFlags.coachWorkspace,
    FeatureFlags.teamHub,
    FeatureFlags.attendanceOperations,
    FeatureFlags.sportTrainingSessions,
  }),
  _Navigator? navigator,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        swanAccessProvider.overrideWithValue(access),
        activeClubProvider.overrideWith((ref) async => club),
        featureFlagsProvider.overrideWith((ref) async => flags),
        teamsProvider.overrideWith(
          (ref) async => const [
            TeamRow(id: 'team-1', name: 'U16'),
            TeamRow(id: 'team-2', name: 'A Takım'),
          ],
        ),
        clubRosterCountsProvider.overrideWith(
          (ref) async => const ClubRosterCounts(total: 11, active: 8),
        ),
        clubTodayAttendanceProvider.overrideWith(
          (ref) async => const ClubTodayAttendance(
            trainingCount: 3,
            markedCount: 2,
          ),
        ),
        attendanceSummaryProvider.overrideWith(
          (ref) async => const [
            AttendanceStat(
              athleteId: 'a1',
              name: 'A',
              present: 1,
              absent: 0,
              total: 1,
              rate: 100,
            ),
            AttendanceStat(
              athleteId: 'a2',
              name: 'B',
              present: 1,
              absent: 0,
              total: 1,
              rate: 100,
            ),
            AttendanceStat(
              athleteId: 'a3',
              name: 'C',
              present: 0,
              absent: 1,
              total: 1,
              rate: 0,
            ),
            AttendanceStat(
              athleteId: 'a4',
              name: 'D',
              present: 1,
              absent: 0,
              total: 1,
              rate: 100,
            ),
          ],
        ),
        trainingProtocolsProvider.overrideWith(
          (ref) async => const [
            _protocol,
            _protocol,
            _protocol,
          ],
        ),
        myLiveSessionProvider.overrideWith(
          (ref) async => const TrainingSession(
            id: 'session-1',
            clubId: 'club-1',
            kind: 'club',
            status: 'live',
            phase: SessionPhase.shoot,
            currentSet: 1,
            setCount: 3,
            rhythm: SessionRhythm.shared,
            protocolName: 'Sabah Kuvvet',
          ),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ProFeatureHostScope(
            navigator: navigator ?? _Navigator(),
            chrome: const _Chrome(),
            theme: ProFeatureThemeData.light,
            child: const SingleChildScrollView(
              child: SharedClubOperationsPanel(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _protocol = TrainingProtocol(
  id: 'protocol-1',
  name: 'Şablon',
  sportCode: 'football',
  version: 1,
  config: TrainingProtocolConfig(
    setCount: 3,
    unitsPerSet: 6,
    prepSeconds: 10,
    shootSeconds: 60,
    collectSeconds: 30,
    restSeconds: 0,
    maxUnitScore: 10,
    entryMode: ScoreEntryMode.flexible,
    mode: TrainingMode.technique,
    archetype: TrainingArchetype.targetScore,
  ),
);

final class _Navigator extends ProFeatureNavigatorBase {
  final calls = <String>[];

  @override
  void openTeams() => calls.add('teams');
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openAttendance() => calls.add('attendance');
  @override
  void openAttendanceHistory() => calls.add('attendance-history');
  @override
  void openTrainingList() => calls.add('training-list');
  @override
  void openTrainingProtocols() => calls.add('training-protocols');
  @override
  void openTrainingBuilder() => calls.add('training-builder');
  @override
  void openTrainingSession({String? sessionId}) =>
      calls.add('training-session:$sessionId');
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
      body;
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

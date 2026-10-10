import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/training/presentation/session_result_screen.dart';
import 'package:swansport_app/features/training/presentation/session_screen.dart';
import 'package:swansport_app/features/training/presentation/widgets/branch_drill_pad.dart';
import 'package:swansport_app/features/training/presentation/widgets/phase_timer.dart';
import 'package:swansport_data/swansport_data.dart';

TrainingProtocolConfig config(TrainingArchetype a) => TrainingProtocolConfig(
  setCount: 3,
  unitsPerSet: 3,
  prepSeconds: 5,
  shootSeconds: 60,
  collectSeconds: a == TrainingArchetype.targetScore ? 20 : 0,
  restSeconds: 10,
  maxUnitScore: 10,
  entryMode: ScoreEntryMode.detailed,
  mode: TrainingMode.technique,
  archetype: a,
);
TrainingSession session(
  TrainingArchetype a, {
  bool coach = false,
  bool paused = false,
  int set = 1,
  String status = 'live',
}) => TrainingSession(
  id: 's',
  clubId: 'club',
  kind: coach ? 'club' : 'personal',
  status: status,
  phase: status != 'live'
      ? SessionPhase.done
      : switch (a) {
          TrainingArchetype.targetScore => SessionPhase.score,
          TrainingArchetype.lapInterval => SessionPhase.lapActive,
          _ => SessionPhase.activeDrill,
        },
  currentSet: set,
  setCount: 3,
  rhythm: SessionRhythm.individual,
  protocolName: 'Canlı antrenman',
  sportCode: a == TrainingArchetype.attemptDrill ? 'volleyball' : 'archery',
  paused: paused,
);
const staff = SwanAccess(
  isPlatformAdmin: false,
  clubRole: 'coach',
  coachLevel: 1,
  athleteKind: null,
);

class RecordingService extends TrainingSessionService {
  RecordingService()
    : super(
        SupabaseClient(
          'http://localhost',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final List<DrillMetricPayload?> payloads = [];
  final List<({String athlete, String text, String tag})> notes = [];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> submitSet({
    required String sessionId,
    required int setNo,
    num? total,
    List<num?>? entries,
    DrillMetricPayload? metricPayload,
  }) async {
    payloads.add(metricPayload);
    if (pending != null) await pending!.future;
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> submitCoachDrillNote(
    String sessionId,
    String athleteId,
    String note,
    String tag,
  ) async {
    notes.add((athlete: athleteId, text: note, tag: tag));
    if (pending != null) await pending!.future;
    if (fail) throw StateError('offline');
  }
}

Future<void> screen(
  WidgetTester tester,
  TrainingArchetype archetype,
  RecordingService service, {
  bool coach = false,
  bool paused = false,
  double width = 430,
  double textScale = 1,
  bool dark = false,
  String status = 'live',
  List<TrainingSet> sets = const [],
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final s = session(archetype, coach: coach, paused: paused, status: status);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isSupabaseEnabledProvider.overrideWithValue(false),
        swanAccessProvider.overrideWithValue(coach ? staff : SwanAccess.none),
        myLiveSessionProvider.overrideWith((ref) async => s),
        trainingSessionProvider('s').overrideWith((ref) async => s),
        sessionConfigProvider(
          's',
        ).overrideWith((ref) async => config(archetype)),
        mySessionSetsProvider('s').overrideWith((ref) async => sets),
        sessionParticipantsProvider('s').overrideWith(
          (ref) async => const [
            SessionParticipant(athleteId: 'a', name: 'Ada'),
          ],
        ),
        sessionCoachDrillNotesProvider(
          's',
        ).overrideWith((ref) async => const []),
        trainingSessionServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TrainingSessionScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('completed coach session keeps result entry, closes notes', (
    tester,
  ) async {
    await screen(
      tester,
      TrainingArchetype.attemptDrill,
      RecordingService(),
      coach: true,
      status: 'completed',
    );
    expect(find.text('Sonuçları incele'), findsOneWidget);
    expect(find.text('Hızlı antrenör notu'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('result route shows lap summary and never archery statistics', (
    tester,
  ) async {
    final s = session(
      TrainingArchetype.lapInterval,
      coach: true,
      status: 'completed',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(false),
          swanAccessProvider.overrideWithValue(staff),
          trainingSessionProvider('s').overrideWith((ref) async => s),
          sessionConfigProvider(
            's',
          ).overrideWith((ref) async => config(TrainingArchetype.lapInterval)),
          sessionOverviewProvider('s').overrideWith((ref) async => null),
          sessionSummaryProvider('s').overrideWith(
            (ref) async => [
              SessionSummaryRow.fromMap({
                'athlete_id': 'a',
                'athlete_name': 'Ada',
                'sets_done': 2,
                'sets_expected': 3,
                'locked': true,
              }),
            ],
          ),
          sessionMetricSetsProvider('s').overrideWith(
            (ref) async => {
              'a': [
                TrainingSet(
                  id: 'lap1',
                  setNo: 1,
                  locked: true,
                  metricPayload: LapIntervalMetric(
                    lapNumber: 1,
                    splitMillis: 29400,
                    distanceMeters: 50,
                  ),
                ),
                TrainingSet(
                  id: 'lap2',
                  setNo: 2,
                  locked: true,
                  metricPayload: LapIntervalMetric(
                    lapNumber: 2,
                    splitMillis: 30200,
                    distanceMeters: 50,
                  ),
                ),
              ],
            },
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(arguments: {'id': 's'}),
            builder: (_) => const SessionResultScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('En iyi tur: 00:29.40'), findsOneWidget);
    expect(find.text('Ortalama tur: 00:29.80'), findsOneWidget);
    expect(find.text('Toplam mesafe: 100 m'), findsOneWidget);
    expect(find.text('Atış'), findsNothing);
    expect(find.text('Set ort.'), findsNothing);
    expect(find.text('Onayla ve kilitle'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final archetype in TrainingArchetype.values) {
    testWidgets('dark cockpit ${archetype.name} renders', (tester) async {
      await screen(tester, archetype, RecordingService(), dark: true);
      expect(find.byType(BranchDrillPad), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('narrow scaled cockpit ${archetype.name} has no overflow', (
      tester,
    ) async {
      await screen(
        tester,
        archetype,
        RecordingService(),
        width: 320,
        textScale: 1.5,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('TrainingSessionScreen renders ${archetype.name}', (
      tester,
    ) async {
      await screen(tester, archetype, RecordingService());
      expect(find.byType(BranchDrillPad), findsOneWidget);
      expect(find.text('Hızlı antrenör notu'), findsNothing);
      expect(find.text('Okları topla'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('locked and paused pads cannot mutate or submit', (tester) async {
    final svc = RecordingService();
    await screen(
      tester,
      TrainingArchetype.attemptDrill,
      svc,
      sets: [
        TrainingSet(
          id: 'locked',
          setNo: 1,
          locked: true,
          metricPayload: AttemptDrillMetric(
            drillName: 'Servis',
            successful: 16,
            faults: 4,
            totalAttempts: 20,
          ),
        ),
      ],
    );
    expect(find.text('16 / 20'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '+ BAŞARILI'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Seti kaydet'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Seti kaydet'),
          )
          .onPressed,
      isNull,
    );
    expect(svc.payloads, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await screen(tester, TrainingArchetype.attemptDrill, svc, paused: true);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '+ BAŞARILI'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('coach note failure retains custom text for retry', (
    tester,
  ) async {
    final svc = RecordingService()..fail = true;
    await screen(tester, TrainingArchetype.combatRally, svc, coach: true);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Servis açısı iyi');
    await tester.ensureVisible(find.text('Notu kaydet'));
    await tester.tap(find.text('Notu kaydet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not kaydedilemedi:'), findsOneWidget);
    expect(find.text('Servis açısı iyi'), findsOneWidget);
    svc.fail = false;
    await tester.tap(find.text('Notu kaydet'));
    await tester.pumpAndSettle();
    expect(svc.notes.last.text, 'Servis açısı iyi');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'attempt counters serialize, prevent duplicate save, preserve failed draft',
    (tester) async {
      final svc = RecordingService()
        ..pending = Completer<void>()
        ..fail = true;
      await screen(tester, TrainingArchetype.attemptDrill, svc);
      await tester.tap(find.text('+ BAŞARILI'));
      await tester.tap(find.text('+ BAŞARILI'));
      await tester.tap(find.text('− HATA/AUT'));
      await tester.pump();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.ensureVisible(find.text('Seti kaydet'));
      await tester.tap(find.text('Seti kaydet'));
      await tester.pump();
      expect(svc.payloads, hasLength(1));
      expect(
        (svc.payloads.single as AttemptDrillMetric).toMap(),
        containsPair('drill_name', 'Servis'),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kaydediliyor…'),
            )
            .onPressed,
        isNull,
      );
      svc.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Kaydedilemedi:'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      svc.pending = null;
      svc.fail = false;
      await tester.tap(find.text('Seti kaydet'));
      await tester.pumpAndSettle();
      expect((svc.payloads.last as AttemptDrillMetric).totalAttempts, 3);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('target rings retain X and M and rally Ace counts as winner', (
    tester,
  ) async {
    final svc = RecordingService();
    await screen(tester, TrainingArchetype.targetScore, svc);
    await tester.tap(find.widgetWithText(OutlinedButton, 'X'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'M'));
    await tester.pump();
    await tester.ensureVisible(find.text('Seti kaydet'));
    await tester.tap(find.text('Seti kaydet'));
    await tester.pumpAndSettle();
    expect((svc.payloads.single as TargetScoreMetric).marks, ['X', 'M']);
    await tester.pumpWidget(const SizedBox.shrink());
    await screen(tester, TrainingArchetype.combatRally, svc);
    await tester.tap(find.text('Ace'));
    await tester.pump();
    await tester.ensureVisible(find.text('Seti kaydet'));
    await tester.tap(find.text('Seti kaydet'));
    await tester.pumpAndSettle();
    expect((svc.payloads.last as CombatRallyMetric).winners, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'lap history renders without score, a measured split records distance',
    (tester) async {
      final svc = RecordingService();
      await screen(
        tester,
        TrainingArchetype.lapInterval,
        svc,
        sets: [
          TrainingSet(
            id: 'old',
            setNo: 2,
            metricPayload: LapIntervalMetric(
              lapNumber: 2,
              splitMillis: 29400,
              distanceMeters: 50,
            ),
          ),
        ],
      );
      await tester.enterText(find.byType(TextField).first, '50');
      await tester.tap(find.text('Kronometreyi başlat / sürdür'));
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text('TUR AL (SPLIT)'));
      await tester.tap(find.text('TUR AL (SPLIT)'));
      await tester.pumpAndSettle();
      final m = svc.payloads.single as LapIntervalMetric;
      expect(m.splitMillis, greaterThan(0));
      expect(m.distanceMeters, 50);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'assistant coach note needs participant selection and is saved immediately',
    (tester) async {
      final svc = RecordingService()..pending = Completer<void>();
      await screen(tester, TrainingArchetype.attemptDrill, svc, coach: true);
      expect(find.byType(BranchDrillPad), findsNothing);
      await tester.ensureVisible(find.text('Teknik İyi'));
      expect(
        tester
            .widget<ActionChip>(find.widgetWithText(ActionChip, 'Teknik İyi'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ada').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Teknik İyi'));
      await tester.tap(find.text('Teknik İyi'));
      await tester.pump();
      expect(
        svc.notes.single,
        (
          athlete: 'a',
          text: 'Teknik İyi',
          tag: 'Teknik İyi',
        ),
      );
      expect(
        tester
            .widget<ActionChip>(find.widgetWithText(ActionChip, 'Teknik İyi'))
            .onPressed,
        isNull,
      );
      svc.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Antrenör notu kaydedildi.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'paused phase timer shows frozen remainder and untimed phase can advance',
    (tester) async {
      final pause = DateTime.utc(2026);
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseTimer(
            phase: SessionPhase.activeDrill,
            endsAt: pause.add(const Duration(seconds: 40)),
            paused: true,
            pausedAt: pause,
            currentSet: 1,
            setCount: 3,
          ),
        ),
      );
      expect(find.text('00:40'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('00:40'), findsOneWidget);
      var advanced = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PhaseTimer(
            phase: SessionPhase.score,
            endsAt: null,
            paused: false,
            currentSet: 1,
            setCount: 3,
            onExpiredAction: () => advanced = true,
          ),
        ),
      );
      await tester.tap(find.text('Devam et'));
      expect(advanced, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

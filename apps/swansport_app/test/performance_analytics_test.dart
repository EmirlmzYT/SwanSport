import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/performance_analytics/application/performance_controller.dart';
import 'package:swansport_app/features/performance_analytics/domain/performance_analytics.dart';
import 'package:swansport_app/features/performance_analytics/presentation/performance_analytics_screen.dart';
import 'package:swansport_app/features/performance_analytics/presentation/performance_route_args.dart';
import 'package:swansport_app/features/performance_analytics/presentation/performance_workflow_editors.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  test(
      'performance domain filters, permissions, and readiness work deterministically',
      () {
    final repo = FixturePerformanceRepository();
    final profile = repo.profiles.first;
    expect(profile.athleteName, 'Arda Yılmaz');
    expect(const PerformanceFilter(query: 'Arda').matches(profile), isTrue);
    expect(
      const PerformanceFilter(query: 'Basketbol').matches(profile),
      isFalse,
    );

    // Performance permissions check
    expect(
      permissionsForPerformanceRole(PerformanceRole.headCoach)
          .canViewInternalCoachNotes,
      isTrue,
    );
    expect(
      permissionsForPerformanceRole(PerformanceRole.athlete)
          .canViewInternalCoachNotes,
      isFalse,
    );
    expect(
      permissionsForPerformanceRole(PerformanceRole.parent)
          .canViewInternalCoachNotes,
      isFalse,
    );

    // Metrics check
    final metrics = repo.metrics;
    expect(metrics.totalAthletes, 2);
    expect(metrics.assessedThisPeriod, 2);
  });

  testWidgets(
      'performance analytics renders responsively across sizes and dark/light modes',
      (t) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final w in mode == ThemeMode.light
          ? [375.0, 600.0, 768.0, 1024.0, 1440.0]
          : [375.0, 1024.0]) {
        t.view.physicalSize = Size(w, 1000);
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: SwanTheme.light(),
              darkTheme: SwanTheme.dark(),
              themeMode: mode,
              home: const PerformanceAnalyticsScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('performance analytics search and detail navigation work',
      (t) async {
    t.view.physicalSize = const Size(900, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();

    final nav = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/performance-analytics'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('performance-command-center')), findsOneWidget);

    await t.enterText(find.byKey(const Key('performance-search')), 'Arda');
    await t.pump();

    await t.tap(find.byKey(const Key('perf-profile-athlete_1')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('performance-detail-name')), findsOneWidget);
    expect(find.byKey(const Key('confidential-coach-notes')), findsOneWidget);
  });

  test('transparent calculations, freshness and benchmark quality work', () {
    const load = TrainingLoadSummary(
      durationMinutes: 75,
      sessionRpe: 6,
      acuteLoads: [400, 450, 500],
      chronicLoads: [350, 400, 450, 475],
    );
    expect(load.internalLoad, 450);
    expect(load.acuteAverage, 450);
    expect(load.lowSample, isFalse);

    final repo = FixturePerformanceRepository();
    final benchmark = repo.benchmarks.single;
    expect(benchmark.compare(3.92), 'Onaylı aralık içinde');
    expect(
      benchmark.comparisonQuality(double.nan),
      PerformanceDataQuality.invalid,
    );
    expect(
      repo.profiles.first.freshnessAt(DateTime(2026, 7, 24)),
      PerformanceDataQuality.complete,
    );
    expect(
      repo.profiles.last.freshnessAt(DateTime(2026, 7, 24)),
      PerformanceDataQuality.stale,
    );
    expect(
      repo.milestones.first.isOverdue(DateTime(2026, 8, 16)),
      isTrue,
    );
  });

  test('controller enforces privacy scope and permission-aware export', () {
    final controller = PerformanceController(FixturePerformanceRepository());
    controller.changeRole(PerformanceRole.parent);
    expect(controller.state.filteredProfiles, hasLength(1));
    expect(controller.state.canViewPrivateWellness, isFalse);
    controller.requestExport(PerformanceExportFormat.csv);
    expect(controller.state.exports, isEmpty);

    controller.changeRole(PerformanceRole.performanceDirector);
    controller.requestExport(PerformanceExportFormat.csv);
    expect(controller.state.exports.single.notice, contains('tıbbi'));
    expect(controller.state.audit.last.action, contains('dışa aktarma'));

    controller.search('missing');
    expect(controller.state.filteredProfiles, isEmpty);
    controller.resetFilters();
    expect(controller.state.filteredProfiles, hasLength(2));
  });

  testWidgets('coaching intelligence surfaces and privacy-safe export render',
      (t) async {
    t.view.physicalSize = const Size(1024, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const PerformanceAnalyticsScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('performance-team-readiness')), findsOneWidget);
    expect(find.byKey(const Key('performance-dimensions')), findsOneWidget);
    expect(find.byKey(const Key('performance-benchmarks')), findsOneWidget);
    expect(find.byKey(const Key('performance-milestones')), findsOneWidget);
    expect(find.byKey(const Key('performance-insights')), findsOneWidget);
    expect(find.byKey(const Key('performance-audit')), findsOneWidget);
    expect(find.byKey(const Key('performance-export-center')), findsOneWidget);
    expect(find.textContaining('ACL'), findsNothing);
    expect(find.textContaining('Ağrı'), findsNothing);
  });

  test('workflow transitions, sorting and audit are enforced in controller',
      () {
    final controller = PerformanceController(FixturePerformanceRepository());
    final initialAudit = controller.state.audit.length;
    final testSession = controller.state.testSessions.single;
    controller.transitionTestSession(
      testSession.id,
      TestSessionStatus.inProgress,
    );
    expect(
      controller.state.testSessions.single.status,
      TestSessionStatus.inProgress,
    );
    controller.transitionPlan(
      controller.state.plans.single.id,
      PlanStatus.paused,
    );
    controller.publishEvaluation(controller.state.evaluations.single.id);
    controller.transitionReview(
      controller.state.reviewSessions.single.id,
      ReviewStatus.completed,
    );
    expect(controller.state.plans.single.status, PlanStatus.paused);
    expect(
      controller.state.evaluations.single.status,
      WorkflowStatus.published,
    );
    expect(
      controller.state.reviewSessions.single.status,
      ReviewStatus.completed,
    );
    expect(controller.state.audit.length, initialAudit + 4);

    controller.setSort(PerformanceSort.athleteName, ascending: false);
    expect(
      controller.state.filteredProfiles.first.athleteName,
      'Caner Erkin',
    );
    controller.setGroup(PerformanceGroup.position);
    expect(controller.state.group, PerformanceGroup.position);

    controller.changeRole(PerformanceRole.athlete);
    controller.submitSelfAssessment(controller.state.selfAssessments.single.id);
    expect(
      controller.state.selfAssessments.single.status,
      WorkflowStatus.published,
    );
    final deniedStatus = controller.state.testSessions.single.status;
    controller.transitionTestSession(
      testSession.id,
      TestSessionStatus.published,
    );
    expect(controller.state.testSessions.single.status, deniedStatus);
  });

  test('match and training calculations preserve missing-data behavior', () {
    final repo = FixturePerformanceRepository();
    expect(repo.matches.single.eventsPer90, closeTo(32.4, 0.01));
    expect(repo.training.single.averageCompletion, 75);
    const invalidMinutes = MatchPerformanceRecord(
      id: SwanId('invalid'),
      athleteId: SwanId('athlete_1'),
      opponent: 'Rakip',
      competition: 'Test',
      minutes: 0,
      factualEvents: {'Şut': 1},
      coachRating: 3,
      quality: PerformanceDataQuality.incomplete,
    );
    expect(invalidMinutes.eventsPer90, isNull);
  });

  testWidgets('all typed performance workflow routes render and fail safely',
      (t) async {
    t.view.physicalSize = const Size(1024, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator));

    final routes = <(String, Object, Key)>[
      (
        '/performance-team-detail',
        const TeamPerformanceArgs(SwanId('team_u18')),
        const Key('team-performance-detail'),
      ),
      (
        '/performance-test-session',
        const TestSessionArgs(SwanId('test_session_1')),
        const Key('test-session-detail'),
      ),
      (
        '/performance-development-plan',
        const DevelopmentPlanArgs(SwanId('plan_1')),
        const Key('development-plan-detail'),
      ),
      (
        '/performance-review-session',
        const ReviewSessionArgs(SwanId('review_1')),
        const Key('review-session-detail'),
      ),
      (
        '/performance-match-detail',
        const MatchPerformanceArgs(SwanId('match_perf_1')),
        const Key('match-performance-detail'),
      ),
      (
        '/performance-training-detail',
        const TrainingPerformanceArgs(SwanId('training_perf_1')),
        const Key('training-performance-detail'),
      ),
      (
        '/performance-position-detail',
        const PositionAnalysisArgs(SwanId('position_striker')),
        const Key('position-analysis-detail'),
      ),
    ];
    for (final route in routes) {
      unawaited(nav.pushNamed(route.$1, arguments: route.$2));
      await t.pumpAndSettle();
      expect(find.byKey(route.$3), findsOneWidget);
      nav.pop();
      await t.pumpAndSettle();
    }

    unawaited(nav.pushNamed('/performance-test-session'));
    await t.pumpAndSettle();
    expect(find.text('Test oturumu bulunamadı.'), findsOneWidget);
  });

  testWidgets('large text and accessible visualization remain overflow safe',
      (t) async {
    t.view.physicalSize = const Size(375, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const PerformanceAnalyticsScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('performance-interactive-chart')),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('performance-interactive-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('performance-chart-table-alternative')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });

  test('complete workflow saves validate, persist and audit', () {
    final controller = PerformanceController(FixturePerformanceRepository());
    final now = DateTime(2026, 7, 24);
    final auditStart = controller.state.audit.length;
    expect(
      controller.saveTestSession(
        PerformanceTestSession(
          id: const SwanId('test_new'),
          title: 'Yeni Batarya',
          sport: 'Futbol',
          battery: const ['Sprint'],
          date: now,
          location: 'Saha',
          teamId: const SwanId('team_u18'),
          athletes: const [SwanId('athlete_1')],
          assessor: 'Koç',
          status: TestSessionStatus.draft,
          validResults: 1,
          missingResults: 0,
          invalidResults: 0,
          notes: '',
          createdAt: now,
          updatedAt: now,
          entries: const [
            PerformanceTestEntry(
              athleteId: SwanId('athlete_1'),
              testName: 'Sprint',
              result: 4,
              unit: 'sn',
              state: TestEntryState.valid,
              note: '',
            ),
          ],
        ),
      ),
      isTrue,
    );
    expect(
      controller.saveDevelopmentPlan(
        DevelopmentPlan(
          id: const SwanId('plan_new'),
          athleteId: const SwanId('athlete_1'),
          title: 'Teknik Plan',
          owner: 'Koç',
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          focusAreas: const ['Pas'],
          linkedGoals: const [SwanId('goal_1')],
          coachingActions: const ['Haftalık değerlendirme'],
          progress: 0,
          status: PlanStatus.draft,
          notes: '',
        ),
      ),
      isTrue,
    );
    expect(
      controller.saveReviewSession(
        AthleteReviewSession(
          id: const SwanId('review_new'),
          athleteId: const SwanId('athlete_1'),
          coach: 'Koç',
          date: now,
          reviewedMetrics: const ['Sprint'],
          decisions: const ['İnsan kararı'],
          agreedActions: const ['Takip'],
          nextReviewDate: now.add(const Duration(days: 30)),
          status: ReviewStatus.scheduled,
          actionOwners: const {'Takip': 'Koç'},
        ),
      ),
      isTrue,
    );
    controller.changeRole(PerformanceRole.athlete);
    expect(
      controller.saveSelfAssessment(
        const AthleteSelfAssessment(
          id: SwanId('self_new'),
          athleteId: SwanId('athlete_1'),
          context: 'Aylık',
          ratings: {'İlerleme': 4},
          perceivedProgress: 'İlerliyorum',
          challenges: 'Program',
          status: WorkflowStatus.draft,
        ),
      ),
      isTrue,
    );
    expect(controller.state.audit.length, auditStart + 4);
  });

  testWidgets(
      'workflow editors validate, save and confirm unsaved cancellation',
      (t) async {
    t.view.physicalSize = const Size(600, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator));

    unawaited(
      nav.pushNamed(
        '/performance-test-session-editor',
        arguments: const TestSessionEditorArgs(),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('workflow-editor-testSession')),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('workflow-save')));
    await t.pump();
    expect(find.text('Oturum başlığı zorunludur'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Oturum başlığı'),
      'Yeni Test',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Test bataryası (virgülle ayırın)'),
      'Sprint',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, '30m Depar sonucu'),
      '4.1',
    );
    await t.tap(find.byKey(const Key('workflow-save')));
    await t.pump();
    expect(find.text('Kayıt başarıyla kaydedildi.'), findsOneWidget);
    nav.pop();
    await t.pumpAndSettle();

    unawaited(
      nav.pushNamed(
        '/performance-review-session-editor',
        arguments: const ReviewSessionEditorArgs(),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextFormField, 'Koç'),
      'Ahmet Şahin',
    );
    await t.tap(find.byKey(const Key('workflow-cancel')));
    await t.pumpAndSettle();
    expect(find.text('Kaydedilmemiş değişiklikler'), findsOneWidget);
    await t.tap(find.text('Düzenlemeye Dön'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('workflow-editor-reviewSession')),
      findsOneWidget,
    );
  });

  testWidgets('self-assessment editor is ownership and permission scoped',
      (t) async {
    final controller = PerformanceController(FixturePerformanceRepository())
      ..changeRole(PerformanceRole.athlete);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          performanceControllerProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(
          home: Navigator(
            onGenerateRoute: _selfAssessmentTestRoute,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('workflow-editor-selfAssessment')),
      findsOneWidget,
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Bağlam'),
      'Aylık değerlendirme',
    );
    await t.enterText(
      find.widgetWithText(TextFormField, 'Algılanan ilerleme'),
      'Hedefimde ilerliyorum',
    );
    await t.tap(find.byKey(const Key('workflow-save')));
    await t.pump();
    expect(find.text('Kayıt başarıyla kaydedildi.'), findsOneWidget);
  });
}

Route<void> _selfAssessmentTestRoute(RouteSettings settings) =>
    MaterialPageRoute<void>(
      builder: (_) => const SelfAssessmentEditorScreen(
        args: SelfAssessmentEditorArgs(),
      ),
    );

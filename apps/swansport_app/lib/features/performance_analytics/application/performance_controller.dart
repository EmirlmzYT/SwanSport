import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_models/swansport_models.dart';
import '../domain/performance_analytics.dart';

class PerformanceCenterState {
  final List<AthletePerformanceProfile> profiles;
  final List<PerformanceAlert> alerts;
  final List<PerformanceDimensionDefinition> dimensions;
  final List<BenchmarkDefinition> benchmarks;
  final List<DevelopmentMilestone> milestones;
  final List<PerformanceInsight> insights;
  final List<PerformanceAuditEntry> audit;
  final List<PerformanceExportRecord> exports;
  final List<TeamPerformanceRecord> teams;
  final List<PerformanceTestSession> testSessions;
  final List<DevelopmentPlan> plans;
  final List<CoachEvaluation> evaluations;
  final List<AthleteSelfAssessment> selfAssessments;
  final List<AthleteReviewSession> reviewSessions;
  final List<MatchPerformanceRecord> matches;
  final List<TrainingPerformanceRecord> training;
  final List<PositionAnalysisRecord> positions;
  final PerformanceSort sort;
  final PerformanceGroup group;
  final bool ascending;
  final PerformanceCommandCenterMetrics metrics;
  final PerformanceFilter filter;
  final PerformanceRole currentRole;
  final bool loading;

  const PerformanceCenterState({
    required this.profiles,
    required this.alerts,
    required this.dimensions,
    required this.benchmarks,
    required this.milestones,
    required this.insights,
    required this.audit,
    this.exports = const [],
    required this.teams,
    required this.testSessions,
    required this.plans,
    required this.evaluations,
    required this.selfAssessments,
    required this.reviewSessions,
    required this.matches,
    required this.training,
    required this.positions,
    this.sort = PerformanceSort.athleteName,
    this.group = PerformanceGroup.none,
    this.ascending = true,
    required this.metrics,
    required this.filter,
    required this.currentRole,
    this.loading = false,
  });

  PerformancePermissions get permissions =>
      permissionsForPerformanceRole(currentRole);

  List<AthletePerformanceProfile> get filteredProfiles {
    final scoped = switch (currentRole) {
      PerformanceRole.athlete ||
      PerformanceRole.parent =>
        profiles.where((p) => p.id == const SwanId('athlete_1')),
      _ => profiles,
    };
    final result = scoped.where((p) => filter.matches(p)).toList();
    result.sort((a, b) {
      final comparison = switch (sort) {
        PerformanceSort.athleteName => a.athleteName.compareTo(b.athleteName),
        PerformanceSort.latestAssessment =>
          (a.latestAssessmentDate ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
            b.latestAssessmentDate ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        PerformanceSort.readiness =>
          a.availability.index.compareTo(b.availability.index),
        PerformanceSort.goalProgress => (a.activeGoals.isEmpty
                  ? 0
                  : a.activeGoals.first.currentProgressPercent)
              .compareTo(
            b.activeGoals.isEmpty
                ? 0
                : b.activeGoals.first.currentProgressPercent,
          ),
      };
      return ascending ? comparison : -comparison;
    });
    return result;
  }

  bool get canViewPrivateWellness =>
      currentRole == PerformanceRole.athlete ||
      currentRole == PerformanceRole.performanceDirector;

  PerformanceCenterState copyWith({
    List<AthletePerformanceProfile>? profiles,
    List<PerformanceAlert>? alerts,
    List<PerformanceDimensionDefinition>? dimensions,
    List<BenchmarkDefinition>? benchmarks,
    List<DevelopmentMilestone>? milestones,
    List<PerformanceInsight>? insights,
    List<PerformanceAuditEntry>? audit,
    List<PerformanceExportRecord>? exports,
    List<TeamPerformanceRecord>? teams,
    List<PerformanceTestSession>? testSessions,
    List<DevelopmentPlan>? plans,
    List<CoachEvaluation>? evaluations,
    List<AthleteSelfAssessment>? selfAssessments,
    List<AthleteReviewSession>? reviewSessions,
    List<MatchPerformanceRecord>? matches,
    List<TrainingPerformanceRecord>? training,
    List<PositionAnalysisRecord>? positions,
    PerformanceSort? sort,
    PerformanceGroup? group,
    bool? ascending,
    PerformanceCommandCenterMetrics? metrics,
    PerformanceFilter? filter,
    PerformanceRole? currentRole,
    bool? loading,
  }) {
    return PerformanceCenterState(
      profiles: profiles ?? this.profiles,
      alerts: alerts ?? this.alerts,
      dimensions: dimensions ?? this.dimensions,
      benchmarks: benchmarks ?? this.benchmarks,
      milestones: milestones ?? this.milestones,
      insights: insights ?? this.insights,
      audit: audit ?? this.audit,
      exports: exports ?? this.exports,
      teams: teams ?? this.teams,
      testSessions: testSessions ?? this.testSessions,
      plans: plans ?? this.plans,
      evaluations: evaluations ?? this.evaluations,
      selfAssessments: selfAssessments ?? this.selfAssessments,
      reviewSessions: reviewSessions ?? this.reviewSessions,
      matches: matches ?? this.matches,
      training: training ?? this.training,
      positions: positions ?? this.positions,
      sort: sort ?? this.sort,
      group: group ?? this.group,
      ascending: ascending ?? this.ascending,
      metrics: metrics ?? this.metrics,
      filter: filter ?? this.filter,
      currentRole: currentRole ?? this.currentRole,
      loading: loading ?? this.loading,
    );
  }
}

class PerformanceController extends StateNotifier<PerformanceCenterState> {
  final FixturePerformanceRepository _repository;

  PerformanceController(this._repository)
      : super(
          PerformanceCenterState(
            profiles: _repository.profiles,
            alerts: _repository.alerts,
            dimensions: _repository.dimensions,
            benchmarks: _repository.benchmarks,
            milestones: _repository.milestones,
            insights: _repository.insights,
            audit: _repository.audit,
            teams: _repository.teams,
            testSessions: _repository.testSessions,
            plans: _repository.plans,
            evaluations: _repository.evaluations,
            selfAssessments: _repository.selfAssessments,
            reviewSessions: _repository.reviewSessions,
            matches: _repository.matches,
            training: _repository.training,
            positions: _repository.positions,
            metrics: _repository.metrics,
            filter: const PerformanceFilter(),
            currentRole: PerformanceRole.headCoach,
          ),
        );

  void search(String query) {
    state = state.copyWith(
      filter: PerformanceFilter(
        query: query,
        team: state.filter.team,
        availability: state.filter.availability,
        onlyGoalsAtRisk: state.filter.onlyGoalsAtRisk,
      ),
    );
  }

  void filterAvailability(PerformanceAvailabilityStatus? availability) {
    state = state.copyWith(
      filter: PerformanceFilter(
        query: state.filter.query,
        team: state.filter.team,
        availability: availability,
        onlyGoalsAtRisk: state.filter.onlyGoalsAtRisk,
      ),
    );
  }

  void filterGoalsAtRisk(bool? goalsAtRisk) {
    state = state.copyWith(
      filter: PerformanceFilter(
        query: state.filter.query,
        team: state.filter.team,
        availability: state.filter.availability,
        onlyGoalsAtRisk: goalsAtRisk,
      ),
    );
  }

  void resetFilters() {
    state = state.copyWith(filter: const PerformanceFilter());
  }

  void setSort(PerformanceSort sort, {bool? ascending}) {
    state = state.copyWith(
      sort: sort,
      ascending: ascending ?? state.sort != sort || !state.ascending,
    );
  }

  void setGroup(PerformanceGroup group) => state = state.copyWith(group: group);

  bool get _canCoachMutate =>
      state.permissions.canManageTests || state.permissions.canAssessSkills;

  void transitionTestSession(SwanId id, TestSessionStatus status) {
    if (!state.permissions.canManageTests) return;
    state = state.copyWith(
      testSessions: [
        for (final session in state.testSessions)
          if (session.id == id)
            session.copyWith(status: status, updatedAt: DateTime.now())
          else
            session,
      ],
    );
    _audit('Test session ${status.name}', id.value);
  }

  bool saveTestSession(PerformanceTestSession session) {
    if (!state.permissions.canManageTests ||
        session.title.trim().isEmpty ||
        session.battery.isEmpty ||
        session.athletes.isEmpty ||
        session.entries.any((e) => !e.isValid)) {
      return false;
    }
    final exists = state.testSessions.any((e) => e.id == session.id);
    state = state.copyWith(
      testSessions: exists
          ? [
              for (final item in state.testSessions)
                if (item.id == session.id) session else item,
            ]
          : [...state.testSessions, session],
    );
    _audit(
      exists ? 'Test session edited' : 'Test session created',
      session.id.value,
    );
    return true;
  }

  void transitionPlan(SwanId id, PlanStatus status) {
    if (!state.permissions.canManageGoals) return;
    state = state.copyWith(
      plans: [
        for (final plan in state.plans)
          if (plan.id == id) plan.copyWith(status: status) else plan,
      ],
    );
    _audit('Development plan ${status.name}', id.value);
  }

  bool saveDevelopmentPlan(DevelopmentPlan plan) {
    if (!state.permissions.canManageGoals ||
        plan.title.trim().isEmpty ||
        plan.owner.trim().isEmpty ||
        !plan.endDate.isAfter(plan.startDate) ||
        plan.focusAreas.isEmpty ||
        plan.coachingActions.isEmpty) {
      return false;
    }
    final exists = state.plans.any((e) => e.id == plan.id);
    state = state.copyWith(
      plans: exists
          ? [
              for (final item in state.plans)
                if (item.id == plan.id) plan else item,
            ]
          : [...state.plans, plan],
    );
    _audit(
      exists ? 'Development plan edited' : 'Development plan created',
      plan.id.value,
    );
    return true;
  }

  void publishEvaluation(SwanId id) {
    if (!_canCoachMutate) return;
    final evaluation = state.evaluations.firstWhere((e) => e.id == id);
    if (!evaluation.isValid) return;
    state = state.copyWith(
      evaluations: [
        for (final item in state.evaluations)
          if (item.id == id)
            item.copyWith(status: WorkflowStatus.published)
          else
            item,
      ],
    );
    _audit('Coach evaluation published', id.value);
  }

  void submitSelfAssessment(SwanId id) {
    final assessment = state.selfAssessments.firstWhere((e) => e.id == id);
    final owns = state.currentRole == PerformanceRole.athlete &&
        assessment.athleteId == const SwanId('athlete_1');
    if (!owns) return;
    state = state.copyWith(
      selfAssessments: [
        for (final item in state.selfAssessments)
          if (item.id == id)
            item.copyWith(status: WorkflowStatus.published)
          else
            item,
      ],
    );
    _audit('Athlete self-assessment submitted', id.value);
  }

  bool saveSelfAssessment(AthleteSelfAssessment assessment) {
    final owns = state.currentRole == PerformanceRole.athlete &&
        assessment.athleteId == const SwanId('athlete_1');
    if (!owns ||
        assessment.context.trim().isEmpty ||
        assessment.perceivedProgress.trim().isEmpty ||
        assessment.ratings.isEmpty ||
        assessment.ratings.values.any((v) => v < 1 || v > 5)) {
      return false;
    }
    final exists = state.selfAssessments.any((e) => e.id == assessment.id);
    state = state.copyWith(
      selfAssessments: exists
          ? [
              for (final item in state.selfAssessments)
                if (item.id == assessment.id) assessment else item,
            ]
          : [...state.selfAssessments, assessment],
    );
    _audit(
      exists
          ? 'Athlete self-assessment edited'
          : 'Athlete self-assessment created',
      assessment.id.value,
    );
    return true;
  }

  void transitionReview(SwanId id, ReviewStatus status) {
    if (!_canCoachMutate) return;
    state = state.copyWith(
      reviewSessions: [
        for (final item in state.reviewSessions)
          if (item.id == id) item.copyWith(status: status) else item,
      ],
    );
    _audit('Review session ${status.name}', id.value);
  }

  bool saveReviewSession(AthleteReviewSession review) {
    if (!_canCoachMutate ||
        review.coach.trim().isEmpty ||
        review.reviewedMetrics.isEmpty ||
        review.decisions.isEmpty ||
        review.agreedActions.isEmpty ||
        review.nextReviewDate.isBefore(review.date)) {
      return false;
    }
    final exists = state.reviewSessions.any((e) => e.id == review.id);
    state = state.copyWith(
      reviewSessions: exists
          ? [
              for (final item in state.reviewSessions)
                if (item.id == review.id) review else item,
            ]
          : [...state.reviewSessions, review],
    );
    _audit(
      exists ? 'Review session edited' : 'Review session created',
      review.id.value,
    );
    return true;
  }

  void _audit(String action, String entity) {
    state = state.copyWith(
      audit: [
        ...state.audit,
        PerformanceAuditEntry(
          id: SwanId('paudit_${state.audit.length + 1}'),
          actor: state.currentRole.name,
          role: state.currentRole,
          occurredAt: DateTime.now(),
          action: action,
          entity: entity,
          previousValue: 'Önceki durum',
          newValue: action,
          reason: 'Yetkili kullanıcı eylemi',
          scope: 'Rol: ${state.currentRole.name}',
        ),
      ],
    );
  }

  void changeRole(PerformanceRole role) {
    state = state.copyWith(currentRole: role);
  }

  void dismissAlert(SwanId alertId) {
    final updated = state.alerts.where((a) => a.id != alertId).toList();
    state = state.copyWith(alerts: updated);
  }

  void requestExport(PerformanceExportFormat format) {
    if (!state.permissions.canExportReports) return;
    final now = DateTime.now();
    state = state.copyWith(
      exports: [
        ...state.exports,
        PerformanceExportRecord(
          id: SwanId('performance_export_${state.exports.length + 1}'),
          format: format,
          requestedAt: now,
          notice:
              'Demo dışa aktarma; wellness, gizli koç notu ve tıbbi ayrıntı içermez.',
        ),
      ],
      audit: [
        ...state.audit,
        PerformanceAuditEntry(
          id: SwanId('paudit_${state.audit.length + 1}'),
          actor: state.currentRole.name,
          role: state.currentRole,
          occurredAt: now,
          action: 'İzin duyarlı demo dışa aktarma',
          entity: format.name,
          previousValue: 'Yok',
          newValue: 'Demo hazır',
          reason: 'Kullanıcı talebi',
          scope: 'Uygulanan rol ve filtreler',
        ),
      ],
    );
  }

  void updateGoalProgress(SwanId goalId, double newProgressPercent) {
    _repository.updateGoalProgress(goalId, newProgressPercent);
    state = state.copyWith(
      profiles: _repository.profiles,
      metrics: _repository.metrics,
    );
  }
}

final performanceRepositoryProvider = Provider<FixturePerformanceRepository>(
  (ref) => FixturePerformanceRepository(),
);

final performanceControllerProvider =
    StateNotifierProvider<PerformanceController, PerformanceCenterState>(
  (ref) => PerformanceController(ref.watch(performanceRepositoryProvider)),
);

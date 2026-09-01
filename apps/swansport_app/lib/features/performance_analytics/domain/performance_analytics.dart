import 'package:swansport_models/swansport_models.dart';
import 'package:swansport_core/swansport_core.dart';

enum PerformanceRole {
  clubOwner,
  headCoach,
  coach,
  performanceDirector,
  scCoach,
  medicalStaff,
  athlete,
  parent,
  auditor,
}

enum PerformanceAvailabilityStatus {
  available,
  limited,
  unavailable,
}

enum PerformanceDimensionCategory {
  physical,
  technical,
  tactical,
  psychological,
  workload,
  wellness,
}

enum GoalStatus {
  draft,
  active,
  onTrack,
  atRisk,
  achieved,
  paused,
  cancelled,
}

enum AssessmentContext {
  trainingDrill,
  match,
  testingSession,
}

enum PerformanceAlertSeverity {
  information,
  warning,
  critical,
}

enum PerformanceDataQuality {
  complete,
  incomplete,
  missing,
  invalid,
  unverified,
  stale,
  lowSample,
  protocolChanged,
}

enum MilestoneStatus { planned, active, completed, overdue }

enum PerformanceExportFormat { pdf, spreadsheet, csv, printableSummary }

enum PerformanceSort { athleteName, latestAssessment, readiness, goalProgress }

enum PerformanceGroup { none, team, position, readiness }

class PerformanceDimensionDefinition {
  final String name;
  final String description;
  final String calculation;
  final String source;
  final String unit;
  final String sport;
  final String owner;
  final String version;
  final DateTime effectiveDate;
  final int freshnessDays;
  final int minimumSample;
  final List<String> exclusions;

  const PerformanceDimensionDefinition({
    required this.name,
    required this.description,
    required this.calculation,
    required this.source,
    required this.unit,
    required this.sport,
    required this.owner,
    required this.version,
    required this.effectiveDate,
    required this.freshnessDays,
    required this.minimumSample,
    required this.exclusions,
  });
}

class TrainingLoadSummary {
  final int durationMinutes;
  final int sessionRpe;
  final List<double> acuteLoads;
  final List<double> chronicLoads;

  const TrainingLoadSummary({
    required this.durationMinutes,
    required this.sessionRpe,
    required this.acuteLoads,
    required this.chronicLoads,
  });

  int get internalLoad => durationMinutes * sessionRpe;
  double? get acuteAverage => acuteLoads.isEmpty
      ? null
      : acuteLoads.reduce((a, b) => a + b) / acuteLoads.length;
  double? get chronicAverage => chronicLoads.isEmpty
      ? null
      : chronicLoads.reduce((a, b) => a + b) / chronicLoads.length;
  bool get lowSample => acuteLoads.length < 3 || chronicLoads.length < 3;
}

class BenchmarkDefinition {
  final SwanId id;
  final String metric;
  final String scope;
  final String source;
  final String version;
  final DateTime effectiveDate;
  final int sampleSize;
  final double lowerBound;
  final double upperBound;
  final String owner;

  const BenchmarkDefinition({
    required this.id,
    required this.metric,
    required this.scope,
    required this.source,
    required this.version,
    required this.effectiveDate,
    required this.sampleSize,
    required this.lowerBound,
    required this.upperBound,
    required this.owner,
  });

  PerformanceDataQuality comparisonQuality(double value) {
    if (sampleSize < 5) return PerformanceDataQuality.lowSample;
    if (!value.isFinite) return PerformanceDataQuality.invalid;
    return PerformanceDataQuality.complete;
  }

  String compare(double value) {
    if (comparisonQuality(value) != PerformanceDataQuality.complete) {
      return 'Karşılaştırma için yetersiz veri';
    }
    if (value < lowerBound) return 'Onaylı aralığın altında';
    if (value > upperBound) return 'Onaylı aralığın üzerinde';
    return 'Onaylı aralık içinde';
  }
}

class ReadinessFactor {
  final String label;
  final String source;
  final String value;
  final DateTime observedAt;
  final bool missing;

  const ReadinessFactor({
    required this.label,
    required this.source,
    required this.value,
    required this.observedAt,
    this.missing = false,
  });
}

class DevelopmentMilestone {
  final SwanId id;
  final String title;
  final DateTime targetDate;
  final DateTime? completedAt;
  final String owner;
  final MilestoneStatus status;
  final String evidence;

  const DevelopmentMilestone({
    required this.id,
    required this.title,
    required this.targetDate,
    this.completedAt,
    required this.owner,
    required this.status,
    required this.evidence,
  });

  bool isOverdue(DateTime now) =>
      completedAt == null && targetDate.isBefore(now);
}

class PerformanceInsight {
  final SwanId id;
  final SwanId athleteId;
  final String reason;
  final String source;
  final String period;
  final PerformanceDataQuality quality;
  final String safeNextAction;

  const PerformanceInsight({
    required this.id,
    required this.athleteId,
    required this.reason,
    required this.source,
    required this.period,
    required this.quality,
    required this.safeNextAction,
  });
}

class PerformanceAuditEntry {
  final SwanId id;
  final String actor;
  final PerformanceRole role;
  final DateTime occurredAt;
  final String action;
  final String entity;
  final String previousValue;
  final String newValue;
  final String reason;
  final String scope;

  const PerformanceAuditEntry({
    required this.id,
    required this.actor,
    required this.role,
    required this.occurredAt,
    required this.action,
    required this.entity,
    required this.previousValue,
    required this.newValue,
    required this.reason,
    required this.scope,
  });
}

class PerformanceExportRecord {
  final SwanId id;
  final PerformanceExportFormat format;
  final DateTime requestedAt;
  final String notice;

  const PerformanceExportRecord({
    required this.id,
    required this.format,
    required this.requestedAt,
    required this.notice,
  });
}

enum TestSessionStatus {
  draft,
  scheduled,
  inProgress,
  completed,
  underReview,
  published,
  archived,
}

enum PlanStatus { draft, active, paused, completed, archived }

enum WorkflowStatus { draft, published, archived }

enum ReviewStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
  followUpRequired,
}

class TeamPerformanceRecord {
  final SwanId id;
  final String name;
  final String branch;
  final String ageGroup;
  final String coach;
  final String period;
  final List<SwanId> athletes;

  const TeamPerformanceRecord({
    required this.id,
    required this.name,
    required this.branch,
    required this.ageGroup,
    required this.coach,
    required this.period,
    required this.athletes,
  });
}

class PerformanceTestSession {
  final SwanId id;
  final String title;
  final String sport;
  final List<String> battery;
  final DateTime date;
  final String location;
  final SwanId teamId;
  final List<SwanId> athletes;
  final String assessor;
  final TestSessionStatus status;
  final int validResults;
  final int missingResults;
  final int invalidResults;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PerformanceTestEntry> entries;

  const PerformanceTestSession({
    required this.id,
    required this.title,
    required this.sport,
    required this.battery,
    required this.date,
    required this.location,
    required this.teamId,
    required this.athletes,
    required this.assessor,
    required this.status,
    required this.validResults,
    required this.missingResults,
    required this.invalidResults,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.entries = const [],
  });

  double get completionProgress {
    final total = validResults + missingResults + invalidResults;
    return total == 0 ? 0 : validResults / total;
  }

  PerformanceTestSession copyWith({
    TestSessionStatus? status,
    int? validResults,
    int? missingResults,
    int? invalidResults,
    DateTime? updatedAt,
    List<PerformanceTestEntry>? entries,
    String? title,
    List<String>? battery,
    List<SwanId>? athletes,
    String? notes,
  }) =>
      PerformanceTestSession(
        id: id,
        title: title ?? this.title,
        sport: sport,
        battery: battery ?? this.battery,
        date: date,
        location: location,
        teamId: teamId,
        athletes: athletes ?? this.athletes,
        assessor: assessor,
        status: status ?? this.status,
        validResults: validResults ?? this.validResults,
        missingResults: missingResults ?? this.missingResults,
        invalidResults: invalidResults ?? this.invalidResults,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        entries: entries ?? this.entries,
      );
}

enum TestEntryState { valid, missing, invalid }

class PerformanceTestEntry {
  final SwanId athleteId;
  final String testName;
  final double? result;
  final String unit;
  final TestEntryState state;
  final String note;

  const PerformanceTestEntry({
    required this.athleteId,
    required this.testName,
    this.result,
    required this.unit,
    required this.state,
    required this.note,
  });

  bool get isValid =>
      state != TestEntryState.valid ||
      (result != null && result!.isFinite && result! >= 0);
}

class DevelopmentPlan {
  final SwanId id;
  final SwanId athleteId;
  final String title;
  final String owner;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> focusAreas;
  final List<SwanId> linkedGoals;
  final List<String> coachingActions;
  final double progress;
  final PlanStatus status;
  final String notes;
  final List<DevelopmentMilestone> milestones;
  final String reviewCadence;

  const DevelopmentPlan({
    required this.id,
    required this.athleteId,
    required this.title,
    required this.owner,
    required this.startDate,
    required this.endDate,
    required this.focusAreas,
    required this.linkedGoals,
    required this.coachingActions,
    required this.progress,
    required this.status,
    required this.notes,
    this.milestones = const [],
    this.reviewCadence = 'Aylık',
  });

  DevelopmentPlan copyWith({
    PlanStatus? status,
    double? progress,
    String? title,
    String? owner,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? focusAreas,
    List<SwanId>? linkedGoals,
    List<String>? coachingActions,
    String? notes,
    List<DevelopmentMilestone>? milestones,
    String? reviewCadence,
  }) =>
      DevelopmentPlan(
        id: id,
        athleteId: athleteId,
        title: title ?? this.title,
        owner: owner ?? this.owner,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        focusAreas: focusAreas ?? this.focusAreas,
        linkedGoals: linkedGoals ?? this.linkedGoals,
        coachingActions: coachingActions ?? this.coachingActions,
        progress: progress ?? this.progress,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        milestones: milestones ?? this.milestones,
        reviewCadence: reviewCadence ?? this.reviewCadence,
      );
}

class CoachEvaluation {
  final SwanId id;
  final SwanId athleteId;
  final String evaluator;
  final String context;
  final Map<String, int> dimensionScores;
  final String narrative;
  final WorkflowStatus status;
  final bool confidential;

  const CoachEvaluation({
    required this.id,
    required this.athleteId,
    required this.evaluator,
    required this.context,
    required this.dimensionScores,
    required this.narrative,
    required this.status,
    required this.confidential,
  });

  bool get isValid =>
      evaluator.trim().isNotEmpty &&
      narrative.trim().isNotEmpty &&
      dimensionScores.values.every((v) => v >= 1 && v <= 5);

  CoachEvaluation copyWith({WorkflowStatus? status}) => CoachEvaluation(
        id: id,
        athleteId: athleteId,
        evaluator: evaluator,
        context: context,
        dimensionScores: dimensionScores,
        narrative: narrative,
        status: status ?? this.status,
        confidential: confidential,
      );
}

class AthleteSelfAssessment {
  final SwanId id;
  final SwanId athleteId;
  final String context;
  final Map<String, int> ratings;
  final String perceivedProgress;
  final String challenges;
  final WorkflowStatus status;
  final bool reviewed;

  const AthleteSelfAssessment({
    required this.id,
    required this.athleteId,
    required this.context,
    required this.ratings,
    required this.perceivedProgress,
    required this.challenges,
    required this.status,
    this.reviewed = false,
  });

  AthleteSelfAssessment copyWith({
    WorkflowStatus? status,
    String? context,
    Map<String, int>? ratings,
    String? perceivedProgress,
    String? challenges,
    bool? reviewed,
  }) =>
      AthleteSelfAssessment(
        id: id,
        athleteId: athleteId,
        context: context ?? this.context,
        ratings: ratings ?? this.ratings,
        perceivedProgress: perceivedProgress ?? this.perceivedProgress,
        challenges: challenges ?? this.challenges,
        status: status ?? this.status,
        reviewed: reviewed ?? this.reviewed,
      );
}

class AthleteReviewSession {
  final SwanId id;
  final SwanId athleteId;
  final String coach;
  final DateTime date;
  final List<String> reviewedMetrics;
  final List<String> decisions;
  final List<String> agreedActions;
  final DateTime nextReviewDate;
  final ReviewStatus status;
  final Map<String, String> actionOwners;

  const AthleteReviewSession({
    required this.id,
    required this.athleteId,
    required this.coach,
    required this.date,
    required this.reviewedMetrics,
    required this.decisions,
    required this.agreedActions,
    required this.nextReviewDate,
    required this.status,
    this.actionOwners = const {},
  });

  AthleteReviewSession copyWith({
    ReviewStatus? status,
    String? coach,
    DateTime? date,
    List<String>? reviewedMetrics,
    List<String>? decisions,
    List<String>? agreedActions,
    DateTime? nextReviewDate,
    Map<String, String>? actionOwners,
  }) =>
      AthleteReviewSession(
        id: id,
        athleteId: athleteId,
        coach: coach ?? this.coach,
        date: date ?? this.date,
        reviewedMetrics: reviewedMetrics ?? this.reviewedMetrics,
        decisions: decisions ?? this.decisions,
        agreedActions: agreedActions ?? this.agreedActions,
        nextReviewDate: nextReviewDate ?? this.nextReviewDate,
        status: status ?? this.status,
        actionOwners: actionOwners ?? this.actionOwners,
      );
}

class MatchPerformanceRecord {
  final SwanId id;
  final SwanId athleteId;
  final String opponent;
  final String competition;
  final int minutes;
  final Map<String, int> factualEvents;
  final int coachRating;
  final PerformanceDataQuality quality;

  const MatchPerformanceRecord({
    required this.id,
    required this.athleteId,
    required this.opponent,
    required this.competition,
    required this.minutes,
    required this.factualEvents,
    required this.coachRating,
    required this.quality,
  });

  double? get eventsPer90 => minutes <= 0
      ? null
      : factualEvents.values.fold(0, (a, b) => a + b) * 90 / minutes;
}

class TrainingPerformanceRecord {
  final SwanId id;
  final SwanId athleteId;
  final String session;
  final bool attended;
  final int objectiveCompletion;
  final int technicalCompletion;
  final int tacticalCompletion;
  final TrainingLoadSummary load;

  const TrainingPerformanceRecord({
    required this.id,
    required this.athleteId,
    required this.session,
    required this.attended,
    required this.objectiveCompletion,
    required this.technicalCompletion,
    required this.tacticalCompletion,
    required this.load,
  });

  double get averageCompletion =>
      (objectiveCompletion + technicalCompletion + tacticalCompletion) / 3;
}

class PositionAnalysisRecord {
  final SwanId id;
  final String position;
  final List<String> dimensions;
  final List<String> tests;
  final int athleteCoverage;
  final int sampleSize;
  final PerformanceDataQuality quality;

  const PositionAnalysisRecord({
    required this.id,
    required this.position,
    required this.dimensions,
    required this.tests,
    required this.athleteCoverage,
    required this.sampleSize,
    required this.quality,
  });
}

class PerformancePermissions {
  final bool canViewCommandCenter;
  final bool canManageTests;
  final bool canAssessSkills;
  final bool canManageGoals;
  final bool canViewInternalCoachNotes;
  final bool canExportReports;

  const PerformancePermissions({
    required this.canViewCommandCenter,
    required this.canManageTests,
    required this.canAssessSkills,
    required this.canManageGoals,
    required this.canViewInternalCoachNotes,
    required this.canExportReports,
  });
}

PerformancePermissions permissionsForPerformanceRole(PerformanceRole role) {
  switch (role) {
    case PerformanceRole.headCoach:
    case PerformanceRole.performanceDirector:
      return const PerformancePermissions(
        canViewCommandCenter: true,
        canManageTests: true,
        canAssessSkills: true,
        canManageGoals: true,
        canViewInternalCoachNotes: true,
        canExportReports: true,
      );
    case PerformanceRole.coach:
    case PerformanceRole.scCoach:
      return const PerformancePermissions(
        canViewCommandCenter: true,
        canManageTests: true,
        canAssessSkills: true,
        canManageGoals: true,
        canViewInternalCoachNotes: true,
        canExportReports: false,
      );
    case PerformanceRole.clubOwner:
    case PerformanceRole.auditor:
      return const PerformancePermissions(
        canViewCommandCenter: true,
        canManageTests: false,
        canAssessSkills: false,
        canManageGoals: false,
        canViewInternalCoachNotes: false,
        canExportReports: true,
      );
    case PerformanceRole.medicalStaff:
      return const PerformancePermissions(
        canViewCommandCenter: true,
        canManageTests: false,
        canAssessSkills: false,
        canManageGoals: false,
        canViewInternalCoachNotes: false,
        canExportReports: true,
      );
    case PerformanceRole.athlete:
    case PerformanceRole.parent:
      return const PerformancePermissions(
        canViewCommandCenter: false,
        canManageTests: false,
        canAssessSkills: false,
        canManageGoals: false,
        canViewInternalCoachNotes: false,
        canExportReports: false,
      );
  }
}

class PhysicalTestResult {
  final String testName;
  final String category;
  final double score;
  final String unit;
  final bool isPersonalBest;
  final DateTime testDate;
  final String assessor;

  const PhysicalTestResult({
    required this.testName,
    required this.category,
    required this.score,
    required this.unit,
    required this.isPersonalBest,
    required this.testDate,
    required this.assessor,
  });
}

class TechnicalSkillRating {
  final String skillName;
  final String category;
  final int rating; // 1 to 5
  final String comments;
  final String assessor;

  const TechnicalSkillRating({
    required this.skillName,
    required this.category,
    required this.rating,
    required this.comments,
    required this.assessor,
  });
}

class TacticalAssessment {
  final String area;
  final int rating; // 1 to 5
  final String comments;
  final String matchContext;
  final String assessor;

  const TacticalAssessment({
    required this.area,
    required this.rating,
    required this.comments,
    required this.matchContext,
    required this.assessor,
  });
}

class IndividualDevelopmentPlanGoal {
  final SwanId id;
  final String title;
  final String category;
  final double baseline;
  final double target;
  final double currentProgressPercent;
  final GoalStatus status;
  final DateTime targetDate;

  const IndividualDevelopmentPlanGoal({
    required this.id,
    required this.title,
    required this.category,
    required this.baseline,
    required this.target,
    required this.currentProgressPercent,
    required this.status,
    required this.targetDate,
  });
}

class AthletePerformanceProfile {
  final SwanId id;
  final String athleteName;
  final String team;
  final String position;
  final PerformanceAvailabilityStatus availability;
  final List<PhysicalTestResult> physicalTests;
  final List<TechnicalSkillRating> technicalSkills;
  final List<TacticalAssessment> tacticalAssessments;
  final List<IndividualDevelopmentPlanGoal> activeGoals;
  final int workloadRpe;
  final int wellnessScore; // 1 to 5
  final String? confidentialCoachNotes;

  const AthletePerformanceProfile({
    required this.id,
    required this.athleteName,
    required this.team,
    required this.position,
    required this.availability,
    required this.physicalTests,
    required this.technicalSkills,
    required this.tacticalAssessments,
    required this.activeGoals,
    required this.workloadRpe,
    required this.wellnessScore,
    this.confidentialCoachNotes,
  });

  bool get hasGoalsAtRisk =>
      activeGoals.any((g) => g.status == GoalStatus.atRisk);

  DateTime? get latestAssessmentDate {
    if (physicalTests.isEmpty) return null;
    return physicalTests
        .map((t) => t.testDate)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  PerformanceDataQuality freshnessAt(DateTime now) {
    final latest = latestAssessmentDate;
    if (latest == null) return PerformanceDataQuality.missing;
    return now.difference(latest).inDays > 45
        ? PerformanceDataQuality.stale
        : PerformanceDataQuality.complete;
  }
}

class PerformanceAlert {
  final SwanId id;
  final String title;
  final String message;
  final PerformanceAlertSeverity severity;
  final SwanId athleteId;
  final String athleteName;

  const PerformanceAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.athleteId,
    required this.athleteName,
  });
}

class PerformanceCommandCenterMetrics {
  final int totalAthletes;
  final int assessedThisPeriod;
  final int awaitingAssessment;
  final int teamReadinessRate;
  final int averageGoalCompletion;
  final int workloadWarningsCount;
  final int dataQualityWarningsCount;

  const PerformanceCommandCenterMetrics({
    required this.totalAthletes,
    required this.assessedThisPeriod,
    required this.awaitingAssessment,
    required this.teamReadinessRate,
    required this.averageGoalCompletion,
    required this.workloadWarningsCount,
    required this.dataQualityWarningsCount,
  });
}

class PerformanceFilter {
  final String query;
  final String? team;
  final PerformanceAvailabilityStatus? availability;
  final bool? onlyGoalsAtRisk;

  const PerformanceFilter({
    this.query = '',
    this.team,
    this.availability,
    this.onlyGoalsAtRisk,
  });

  bool matches(AthletePerformanceProfile profile) {
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final matchName = trContains(profile.athleteName, q);
      final matchTeam = trContains(profile.team, q);
      final matchPos = trContains(profile.position, q);
      if (!matchName && !matchTeam && !matchPos) return false;
    }
    if (team != null && profile.team != team) return false;
    if (availability != null && profile.availability != availability) {
      return false;
    }
    if (onlyGoalsAtRisk == true && !profile.hasGoalsAtRisk) return false;
    return true;
  }
}

class FixturePerformanceRepository {
  final List<TeamPerformanceRecord> _teams = const [
    TeamPerformanceRecord(
      id: SwanId('team_u18'),
      name: 'U18 Elite',
      branch: 'Kadıköy',
      ageGroup: 'U18',
      coach: 'Ahmet Şahin',
      period: '2026 Temmuz',
      athletes: [SwanId('athlete_1')],
    ),
  ];
  final List<PerformanceTestSession> _testSessions = [
    PerformanceTestSession(
      id: const SwanId('test_session_1'),
      title: 'U18 Temmuz Fiziksel Test Bataryası',
      sport: 'Futbol',
      battery: const ['30m Depar', 'Yo-Yo IR1'],
      date: DateTime(2026, 7, 28),
      location: 'Kadıköy Performans Sahası',
      teamId: const SwanId('team_u18'),
      athletes: const [SwanId('athlete_1')],
      assessor: 'Performans Direktörü',
      status: TestSessionStatus.scheduled,
      validResults: 0,
      missingResults: 2,
      invalidResults: 0,
      notes: 'Manuel, onaylı protokol.',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
    ),
  ];
  final List<DevelopmentPlan> _plans = [
    DevelopmentPlan(
      id: const SwanId('plan_1'),
      athleteId: const SwanId('athlete_1'),
      title: 'U18 Teknik Gelişim Planı',
      owner: 'Ahmet Şahin',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 10, 1),
      focusAreas: const ['Zayıf ayak kullanımı', 'Karar verme'],
      linkedGoals: const [SwanId('goal_1')],
      coachingActions: const ['Haftalık teknik değerlendirme'],
      progress: 55,
      status: PlanStatus.active,
      notes: 'Tıbbi rehabilitasyon içermez.',
    ),
  ];
  final List<CoachEvaluation> _evaluations = const [
    CoachEvaluation(
      id: SwanId('evaluation_1'),
      athleteId: SwanId('athlete_1'),
      evaluator: 'Ahmet Şahin',
      context: 'Aylık koç değerlendirmesi',
      dimensionScores: {'Teknik': 4, 'Taktik': 4},
      narrative: 'İnsan değerlendirmesi; ölçülmüş gerçek değildir.',
      status: WorkflowStatus.draft,
      confidential: true,
    ),
  ];
  final List<AthleteSelfAssessment> _selfAssessments = const [
    AthleteSelfAssessment(
      id: SwanId('self_1'),
      athleteId: SwanId('athlete_1'),
      context: 'Aylık öz değerlendirme',
      ratings: {'Algılanan ilerleme': 4},
      perceivedProgress: 'Teknik hedefimde ilerlediğimi düşünüyorum.',
      challenges: 'Yoğun program.',
      status: WorkflowStatus.draft,
    ),
  ];
  final List<AthleteReviewSession> _reviewSessions = [
    AthleteReviewSession(
      id: const SwanId('review_1'),
      athleteId: const SwanId('athlete_1'),
      coach: 'Ahmet Şahin',
      date: DateTime(2026, 7, 30),
      reviewedMetrics: const ['30m Depar', 'Teknik hedef'],
      decisions: const ['İnsan sahipliğinde değerlendirme sürdürülecek'],
      agreedActions: const ['Bir sonraki ölçümü planla'],
      nextReviewDate: DateTime(2026, 8, 30),
      status: ReviewStatus.scheduled,
    ),
  ];
  final List<MatchPerformanceRecord> _matches = const [
    MatchPerformanceRecord(
      id: SwanId('match_perf_1'),
      athleteId: SwanId('athlete_1'),
      opponent: 'Rakip U18',
      competition: 'Hazırlık Maçı',
      minutes: 75,
      factualEvents: {'Şut': 3, 'Pas': 24},
      coachRating: 4,
      quality: PerformanceDataQuality.complete,
    ),
  ];
  final List<TrainingPerformanceRecord> _training = const [
    TrainingPerformanceRecord(
      id: SwanId('training_perf_1'),
      athleteId: SwanId('athlete_1'),
      session: 'Teknik Antrenman 24 Temmuz',
      attended: true,
      objectiveCompletion: 80,
      technicalCompletion: 75,
      tacticalCompletion: 70,
      load: TrainingLoadSummary(
        durationMinutes: 70,
        sessionRpe: 6,
        acuteLoads: [380, 420, 400],
        chronicLoads: [350, 375, 390],
      ),
    ),
  ];
  final List<PositionAnalysisRecord> _positions = const [
    PositionAnalysisRecord(
      id: SwanId('position_striker'),
      position: 'Santrafor',
      dimensions: ['Teknik', 'Taktik', 'Fiziksel'],
      tests: ['30m Depar', 'Şut isabeti'],
      athleteCoverage: 3,
      sampleSize: 8,
      quality: PerformanceDataQuality.complete,
    ),
  ];
  final List<PerformanceDimensionDefinition> _dimensions = [
    PerformanceDimensionDefinition(
      name: 'Antrenman İç Yükü',
      description: 'Oturum süresi ve sporcu RPE girdisinden hesaplanır.',
      calculation: 'Süre (dk) × oturum RPE',
      source: 'Antrenman oturumu ve sporcu öz bildirimi',
      unit: 'AU',
      sport: 'Tüm branşlar',
      owner: 'Performans Direktörü',
      version: '1.0',
      effectiveDate: DateTime(2026),
      freshnessDays: 7,
      minimumSample: 3,
      exclusions: const ['Eksik süre', 'Eksik RPE', 'Geçersiz oturum'],
    ),
  ];

  final List<BenchmarkDefinition> _benchmarks = [
    BenchmarkDefinition(
      id: const SwanId('bench_1'),
      metric: '30m Depar',
      scope: 'U18 takım içi tarihsel aralık',
      source: 'Onaylı kulüp test protokolü',
      version: '2.1',
      effectiveDate: DateTime(2026),
      sampleSize: 18,
      lowerBound: 3.7,
      upperBound: 4.3,
      owner: 'Performans Direktörü',
    ),
  ];

  final List<DevelopmentMilestone> _milestones = [
    DevelopmentMilestone(
      id: const SwanId('milestone_1'),
      title: 'Sol ayak isabet ara değerlendirmesi',
      targetDate: DateTime(2026, 8, 15),
      owner: 'Baş Antrenör',
      status: MilestoneStatus.active,
      evidence: 'Onaylı teknik test oturumu',
    ),
  ];

  final List<PerformanceInsight> _insights = [
    const PerformanceInsight(
      id: SwanId('insight_1'),
      athleteId: SwanId('athlete_1'),
      reason: 'Son onaylı sprint sonucu önceki ölçümden daha iyi.',
      source: '30m depar test oturumları',
      period: 'Son iki test',
      quality: PerformanceDataQuality.complete,
      safeNextAction: 'Koç değerlendirmesinde bağlamla birlikte inceleyin.',
    ),
  ];

  final List<PerformanceAuditEntry> _audit = [
    PerformanceAuditEntry(
      id: const SwanId('paudit_1'),
      actor: 'Ahmet Şahin',
      role: PerformanceRole.headCoach,
      occurredAt: DateTime(2026, 7, 2, 11),
      action: 'Test sonucu yayınlandı',
      entity: '30m Depar • athlete_1',
      previousValue: 'Taslak',
      newValue: 'Yayınlandı',
      reason: 'İkinci değerlendirici kontrolü tamamlandı',
      scope: 'U18 Elite',
    ),
  ];

  final List<AthletePerformanceProfile> _profiles = [
    AthletePerformanceProfile(
      id: const SwanId('athlete_1'),
      athleteName: 'Arda Yılmaz',
      team: 'U18 Elite',
      position: 'Santrafor',
      availability: PerformanceAvailabilityStatus.available,
      physicalTests: [
        PhysicalTestResult(
          testName: '30m Depar Testi',
          category: 'Hız',
          score: 3.92,
          unit: 'sn',
          isPersonalBest: true,
          testDate: DateTime(2026, 7, 1),
          assessor: 'Fzt. Burak Şahin',
        ),
        PhysicalTestResult(
          testName: 'Yo-Yo IR1 Testi',
          category: 'Dayanıklılık',
          score: 2160,
          unit: 'm',
          isPersonalBest: false,
          testDate: DateTime(2026, 6, 15),
          assessor: 'Fzt. Burak Şahin',
        ),
      ],
      technicalSkills: const [
        TechnicalSkillRating(
          skillName: 'Şut Tekniği',
          category: 'Hücum',
          rating: 4,
          comments: 'Ceza sahası dışından etkili vuruşlar.',
          assessor: 'Ahmet Şahin (Teknik Sorumlu)',
        ),
      ],
      tacticalAssessments: const [
        TacticalAssessment(
          area: 'Savunma Arkasına Koşu',
          rating: 5,
          comments: 'Zamanlama mükemmel.',
          matchContext: 'Galatasaray U18 Maçı',
          assessor: 'Ahmet Şahin (Teknik Sorumlu)',
        ),
      ],
      activeGoals: [
        IndividualDevelopmentPlanGoal(
          id: const SwanId('goal_1'),
          title: 'Sol Ayak Şut İsabeti %60',
          category: 'Teknik Gelişim',
          baseline: 40,
          target: 60,
          currentProgressPercent: 55,
          status: GoalStatus.onTrack,
          targetDate: DateTime(2026, 8, 30),
        ),
      ],
      workloadRpe: 7,
      wellnessScore: 4,
      confidentialCoachNotes:
          'Oyuncu liderlik potansiyeline sahip. Taktik disiplini yüksek.',
    ),
    AthletePerformanceProfile(
      id: const SwanId('athlete_2'),
      athleteName: 'Caner Erkin',
      team: 'A Takım',
      position: 'Sol Bek',
      availability: PerformanceAvailabilityStatus.limited,
      physicalTests: [
        PhysicalTestResult(
          testName: '30m Depar Testi',
          category: 'Hız',
          score: 4.12,
          unit: 'sn',
          isPersonalBest: false,
          testDate: DateTime(2026, 5, 10),
          assessor: 'Fzt. Burak Şahin',
        ),
      ],
      technicalSkills: const [
        TechnicalSkillRating(
          skillName: 'Orta Yapma',
          category: 'Hücum',
          rating: 5,
          comments: 'Kavisli ve adrese teslim ortalar.',
          assessor: 'Mehmet Öz (Antrenör)',
        ),
      ],
      tacticalAssessments: const [
        TacticalAssessment(
          area: 'Kademeye Girme',
          rating: 3,
          comments: 'Geçiş savunmasında uyarı gerektiriyor.',
          matchContext: 'Hazırlık Maçı',
          assessor: 'Mehmet Öz (Antrenör)',
        ),
      ],
      activeGoals: [
        IndividualDevelopmentPlanGoal(
          id: const SwanId('goal_2'),
          title: 'Operasyonel uygunluk sonrası hareket kalitesi',
          category: 'Koçluk Gelişimi',
          baseline: 60,
          target: 100,
          currentProgressPercent: 70,
          status: GoalStatus.atRisk,
          targetDate: DateTime(2026, 9, 15),
        ),
      ],
      workloadRpe: 5,
      wellnessScore: 3,
      confidentialCoachNotes:
          'Operasyonel kısıtlama geçerlidir; seçim kararı insan incelemesi gerektirir.',
    ),
  ];

  final List<PerformanceAlert> _alerts = [
    const PerformanceAlert(
      id: SwanId('perf_alert_1'),
      title: 'Koç İncelemesi Gerekiyor',
      message:
          'Operasyonel uygunluk kısıtlı. Screen 12 clearance kararı geçerlidir.',
      severity: PerformanceAlertSeverity.warning,
      athleteId: SwanId('athlete_2'),
      athleteName: 'Caner Erkin',
    ),
    const PerformanceAlert(
      id: SwanId('perf_alert_2'),
      title: 'Yeni Kişisel Rekor (PB)',
      message: 'Arda Yılmaz 30m depar testinde 3.92sn ile kişisel rekor kırdı.',
      severity: PerformanceAlertSeverity.information,
      athleteId: SwanId('athlete_1'),
      athleteName: 'Arda Yılmaz',
    ),
  ];

  List<AthletePerformanceProfile> get profiles => List.unmodifiable(_profiles);
  List<PerformanceAlert> get alerts => List.unmodifiable(_alerts);
  List<PerformanceDimensionDefinition> get dimensions =>
      List.unmodifiable(_dimensions);
  List<BenchmarkDefinition> get benchmarks => List.unmodifiable(_benchmarks);
  List<DevelopmentMilestone> get milestones => List.unmodifiable(_milestones);
  List<PerformanceInsight> get insights => List.unmodifiable(_insights);
  List<PerformanceAuditEntry> get audit => List.unmodifiable(_audit);
  List<TeamPerformanceRecord> get teams => List.unmodifiable(_teams);
  List<PerformanceTestSession> get testSessions =>
      List.unmodifiable(_testSessions);
  List<DevelopmentPlan> get plans => List.unmodifiable(_plans);
  List<CoachEvaluation> get evaluations => List.unmodifiable(_evaluations);
  List<AthleteSelfAssessment> get selfAssessments =>
      List.unmodifiable(_selfAssessments);
  List<AthleteReviewSession> get reviewSessions =>
      List.unmodifiable(_reviewSessions);
  List<MatchPerformanceRecord> get matches => List.unmodifiable(_matches);
  List<TrainingPerformanceRecord> get training => List.unmodifiable(_training);
  List<PositionAnalysisRecord> get positions => List.unmodifiable(_positions);

  PerformanceCommandCenterMetrics get metrics {
    final total = _profiles.length;
    final assessed = _profiles.where((p) => p.physicalTests.isNotEmpty).length;
    final ready = _profiles
        .where((p) => p.availability == PerformanceAvailabilityStatus.available)
        .length;
    final readinessRate = total > 0 ? ((ready / total) * 100).round() : 0;
    const avgGoal = 62;

    return PerformanceCommandCenterMetrics(
      totalAthletes: total,
      assessedThisPeriod: assessed,
      awaitingAssessment: total - assessed,
      teamReadinessRate: readinessRate,
      averageGoalCompletion: avgGoal,
      workloadWarningsCount: 1,
      dataQualityWarningsCount: 0,
    );
  }

  void updateGoalProgress(SwanId goalId, double newProgressPercent) {
    // Repository implementation placeholder
  }
}

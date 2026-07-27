enum ReportDomainCategory {
  executive('Executive', '👑 Yönetsel Özet'),
  athlete('Athlete', '🏃 Sporcu Analitiği'),
  team('Team', '👥 Takım & Şube'),
  attendance('Attendance', '📅 Yoklama & Katılım'),
  training('Training', '⏱️ Antrenman & Maç'),
  facility('Facility', '🏟️ Tesis & Salon'),
  medical('Medical', '🩺 Tıbbi & Sağlık Compliance'),
  communication('Communication', '📢 İletişim & Duyuru'),
  document('Document', '📄 Evrak & İzinler');

  const ReportDomainCategory(this.key, this.displayName);
  final String key;
  final String displayName;
}

enum AlertSeverity {
  critical('Kritik', '🔴'),
  warning('Uyarı', '🟡'),
  info('Bilgi', '🔵');

  const AlertSeverity(this.displayName, this.icon);
  final String displayName;
  final String icon;
}

enum ReportCertification {
  draft,
  generated,
  underReview,
  certified,
  rejected,
  expired,
  revoked,
  superseded
}

enum DataFreshness { current, updating, delayed, stale, partial, unavailable }

enum MetricDefinitionState {
  draft,
  underReview,
  certified,
  deprecated,
  retired
}

enum DecisionStatus {
  proposed,
  approved,
  inProgress,
  completed,
  rejected,
  cancelled,
  reviewRequired
}

class MetricDefinition {
  const MetricDefinition({
    required this.key,
    required this.name,
    required this.description,
    required this.calculation,
    required this.source,
    required this.unit,
    required this.owner,
    required this.state,
    required this.version,
    required this.effectiveDate,
  });
  final String key,
      name,
      description,
      calculation,
      source,
      unit,
      owner,
      version;
  final MetricDefinitionState state;
  final DateTime effectiveDate;
}

class InsightCommentary {
  const InsightCommentary({
    required this.author,
    required this.role,
    required this.text,
    required this.timestamp,
    this.resolved = false,
  });
  final String author, role, text;
  final DateTime timestamp;
  final bool resolved;
}

class DecisionRecord {
  const DecisionRecord({
    required this.title,
    required this.owner,
    required this.reason,
    required this.action,
    required this.dueDate,
    required this.status,
  });
  final String title, owner, reason, action;
  final DateTime dueDate;
  final DecisionStatus status;
}

class ReportAuditEntry {
  const ReportAuditEntry({
    required this.actor,
    required this.role,
    required this.action,
    required this.reportId,
    required this.timestamp,
    required this.previousValue,
    required this.newValue,
  });
  final String actor, role, action, reportId, previousValue, newValue;
  final DateTime timestamp;
}

class SavedReportView {
  const SavedReportView({
    required this.id,
    required this.name,
    required this.reportId,
    this.isDefault = false,
    this.archived = false,
  });
  final String id, name, reportId;
  final bool isDefault, archived;
}

class ExecutiveKpi {
  const ExecutiveKpi({
    required this.totalActiveAthletes,
    required this.athleteGrowthPercentage,
    required this.overallAttendanceRate,
    required this.trainingCompletionRate,
    required this.facilityOccupancyRate,
    required this.medicalComplianceScore,
    required this.activeInjuriesCount,
    required this.clubHealthScore,
  });

  final int totalActiveAthletes;
  final double athleteGrowthPercentage;
  final double overallAttendanceRate;
  final double trainingCompletionRate;
  final double facilityOccupancyRate;
  final double medicalComplianceScore;
  final int activeInjuriesCount;
  final int clubHealthScore;
}

class ReportTemplate {
  const ReportTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.requiredRole,
    required this.lastGenerated,
    this.isFavorite = false,
    this.isScheduled = false,
    this.certification = ReportCertification.generated,
    this.freshness = DataFreshness.current,
    this.owner = 'BI Ekibi',
    this.sourceModules = const [],
  });

  final String id;
  final String title;
  final String description;
  final ReportDomainCategory category;
  final String requiredRole;
  final String lastGenerated;
  final bool isFavorite;
  final bool isScheduled;
  final ReportCertification certification;
  final DataFreshness freshness;
  final String owner;
  final List<String> sourceModules;
}

class AnomalyAlert {
  const AnomalyAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    required this.affectedDomain,
  });

  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final String timestamp;
  final String affectedDomain;
}

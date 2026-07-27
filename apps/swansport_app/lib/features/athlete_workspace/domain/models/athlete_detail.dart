import 'package:swansport_models/swansport_models.dart';

enum AthleteDetailSection {
  activity,
  attendance,
  documents,
  notes,
}

enum MedicalRestrictionStatus {
  clear,
  restricted,
  unknown,
}

enum AthleteTimelineEntryType {
  attendance,
  document,
  note,
  medical,
}

class Athlete {
  const Athlete({
    required this.id,
    required this.displayName,
    required this.statusLabel,
  });

  final SwanId id;
  final String displayName;
  final String statusLabel;
}

class AthleteProfile {
  const AthleteProfile({
    required this.athlete,
    required this.initials,
    required this.position,
    required this.birthDateLabel,
    required this.licenseNumber,
    required this.jerseyNumber,
    required this.teamName,
    required this.seasonLabel,
  });

  final Athlete athlete;
  final String initials;
  final String position;
  final String birthDateLabel;
  final String licenseNumber;
  final String jerseyNumber;
  final String teamName;
  final String seasonLabel;
}

class GuardianSummary {
  const GuardianSummary({
    required this.displayName,
    required this.relationship,
    required this.canContact,
  });

  final String displayName;
  final String relationship;
  final bool canContact;
}

class TeamMembership {
  const TeamMembership({
    required this.teamId,
    required this.teamName,
    required this.seasonId,
    required this.seasonLabel,
    required this.jerseyNumber,
  });

  final SwanId teamId;
  final String teamName;
  final SwanId seasonId;
  final String seasonLabel;
  final String jerseyNumber;
}

class SeasonContext {
  const SeasonContext({
    required this.seasonId,
    required this.label,
    required this.isActive,
  });

  final SwanId seasonId;
  final String label;
  final bool isActive;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.rateLabel,
    required this.scoreLabel,
    required this.scoreUnit,
    required this.recentItems,
  });

  final String rateLabel;
  final String scoreLabel;
  final String scoreUnit;
  final List<AttendanceHistoryItem> recentItems;
}

class AttendanceHistoryItem {
  const AttendanceHistoryItem({
    required this.dateLabel,
    required this.sessionLabel,
    required this.statusLabel,
  });

  final String dateLabel;
  final String sessionLabel;
  final String statusLabel;
}

class MedicalRestrictionSummary {
  const MedicalRestrictionSummary({
    required this.status,
    required this.title,
    required this.summary,
  });

  final MedicalRestrictionStatus status;
  final String title;
  final String summary;
}

class AthleteDocumentSummary {
  const AthleteDocumentSummary({
    required this.id,
    required this.title,
    required this.statusLabel,
  });

  final SwanId id;
  final String title;
  final String statusLabel;
}

class CoachNote {
  const CoachNote({
    required this.id,
    required this.authorName,
    required this.dateLabel,
    required this.body,
  });

  final SwanId id;
  final String authorName;
  final String dateLabel;
  final String body;
}

class AthleteTimelineEntry {
  const AthleteTimelineEntry({
    required this.id,
    required this.type,
    required this.timeLabel,
    required this.title,
    required this.summary,
  });

  final SwanId id;
  final AthleteTimelineEntryType type;
  final String timeLabel;
  final String title;
  final String summary;
}

class AthleteDetail {
  const AthleteDetail({
    required this.profile,
    required this.guardian,
    required this.membership,
    required this.season,
    required this.attendance,
    required this.medical,
    required this.documents,
    required this.notes,
    required this.timeline,
    required this.lastSyncedLabel,
  });

  final AthleteProfile profile;
  final GuardianSummary guardian;
  final TeamMembership membership;
  final SeasonContext season;
  final AttendanceSummary attendance;
  final MedicalRestrictionSummary medical;
  final List<AthleteDocumentSummary> documents;
  final List<CoachNote> notes;
  final List<AthleteTimelineEntry> timeline;
  final String lastSyncedLabel;

  AthleteDetail copyWith({
    AthleteProfile? profile,
    GuardianSummary? guardian,
    TeamMembership? membership,
    SeasonContext? season,
    AttendanceSummary? attendance,
    MedicalRestrictionSummary? medical,
    List<AthleteDocumentSummary>? documents,
    List<CoachNote>? notes,
    List<AthleteTimelineEntry>? timeline,
    String? lastSyncedLabel,
  }) {
    return AthleteDetail(
      profile: profile ?? this.profile,
      guardian: guardian ?? this.guardian,
      membership: membership ?? this.membership,
      season: season ?? this.season,
      attendance: attendance ?? this.attendance,
      medical: medical ?? this.medical,
      documents: documents ?? this.documents,
      notes: notes ?? this.notes,
      timeline: timeline ?? this.timeline,
      lastSyncedLabel: lastSyncedLabel ?? this.lastSyncedLabel,
    );
  }
}

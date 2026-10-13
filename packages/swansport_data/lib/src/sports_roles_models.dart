// Pure Dart, explicit projections only. No identity/guardian/clinical payloads.
enum FederationRoleKind {
  president('president'), boardMember('board_member'),
  generalSecretary('general_secretary'), provincialRep('provincial_rep'),
  refereeCommittee('referee_committee'), disciplinaryBoard('disciplinary_board');
  const FederationRoleKind(this.wireName);
  final String wireName;
}

enum RefereeBadgeTier {
  candidate('candidate'), provincial('provincial'), national('national'),
  international('international');
  const RefereeBadgeTier(this.wireName);
  final String wireName;
}

enum MatchOfficialDuty {
  headReferee('head_referee'), assistantReferee1('assistant_referee_1'),
  assistantReferee2('assistant_referee_2'), fourthReferee('fourth_referee'),
  tableOfficial('table_official'), observer('observer');
  const MatchOfficialDuty(this.wireName);
  final String wireName;
}

enum MatchOfficialStatus { assigned, accepted, declined, replaced }
enum MatchLineupSide { home, away }

enum ClubStaffRoleKind {
  president('president'), sportingDirector('sporting_director'), doctor('doctor'),
  physiotherapist('physiotherapist'), kitManager('kit_manager'),
  mediaOfficer('media_officer');
  const ClubStaffRoleKind(this.wireName);
  final String wireName;
}

T _decode<T>(Iterable<T> values, String Function(T) key, Object? raw) =>
    values.firstWhere((v) => key(v) == raw,
      orElse: () => throw FormatException('Unknown sports role value: $raw'));
DateTime _date(Map<String, dynamic> m, String key) => DateTime.parse(m[key] as String);
DateTime? _optionalDate(Map<String, dynamic> m, String key) =>
    m[key] == null ? null : _date(m, key);

class FederationRole {
  const FederationRole({required this.id, required this.federationId,
    required this.profileId, required this.role, this.cityCode,
    required this.startsOn, required this.endsOn, bool isActive = true,
    this.revokedAt}) : _enabled = isActive;
  final String id;
  final String federationId;
  final String profileId;
  final FederationRoleKind role;
  final String? cityCode;
  final DateTime startsOn;
  final DateTime endsOn;
  final DateTime? revokedAt;
  final bool _enabled;

  // 0110 has no is_active column: revocation + inclusive Turkey calendar dates.
  bool get isActive => isActiveOn(DateTime.now());
  bool isActiveOn(DateTime instant) {
    final local = instant.toUtc().add(const Duration(hours: 3));
    final day = DateTime.utc(local.year, local.month, local.day);
    return _enabled && revokedAt == null &&
      !day.isBefore(DateTime.utc(startsOn.year, startsOn.month, startsOn.day)) &&
      !day.isAfter(DateTime.utc(endsOn.year, endsOn.month, endsOn.day));
  }
  factory FederationRole.fromMap(Map<String, dynamic> m) => FederationRole(
    id: m['id'] as String, federationId: m['federation_id'] as String,
    profileId: m['profile_id'] as String,
    role: _decode(FederationRoleKind.values, (v) => v.wireName, m['role']),
    cityCode: m['city_code'] as String?, startsOn: _date(m, 'starts_on'),
    endsOn: _date(m, 'ends_on'), revokedAt: _optionalDate(m, 'revoked_at'),
    isActive: m['is_active'] as bool? ?? true);
  factory FederationRole.fromJson(Map<String, dynamic> m) => FederationRole.fromMap(m);
}

class RefereeProfile {
  const RefereeProfile({required this.id, required this.profileId,
    required this.licenseNumber, required this.badgeTier, required this.sportCode,
    required this.cityCode, required this.isActive});
  final String id;
  final String profileId;
  final String licenseNumber;
  final RefereeBadgeTier badgeTier;
  final String sportCode;
  final String cityCode;
  final bool isActive;
  factory RefereeProfile.fromMap(Map<String, dynamic> m) => RefereeProfile(
    id: m['id'] as String, profileId: m['profile_id'] as String,
    licenseNumber: m['license_number'] as String,
    badgeTier: _decode(RefereeBadgeTier.values, (v) => v.wireName, m['badge_tier']),
    sportCode: m['sport_code'] as String, cityCode: m['city_code'] as String,
    isActive: m['is_active'] as bool);
  factory RefereeProfile.fromJson(Map<String, dynamic> m) => RefereeProfile.fromMap(m);
}

class MatchOfficial {
  const MatchOfficial({required this.id, required this.matchId,
    required this.profileId, required this.duty, required this.status,
    this.declineReason, required this.assignedAt, this.respondedAt});
  final String id;
  final String matchId;
  final String profileId;
  final MatchOfficialDuty duty;
  final MatchOfficialStatus status;
  final String? declineReason;
  final DateTime assignedAt;
  final DateTime? respondedAt;
  factory MatchOfficial.fromMap(Map<String, dynamic> m) => MatchOfficial(
    id: m['id'] as String, matchId: m['match_id'] as String,
    profileId: m['profile_id'] as String,
    duty: _decode(MatchOfficialDuty.values, (v) => v.wireName, m['duty']),
    status: _decode(MatchOfficialStatus.values, (v) => v.name, m['status']),
    declineReason: m['decline_reason'] as String?,
    assignedAt: _date(m, 'assigned_at'), respondedAt: _optionalDate(m, 'responded_at'));
  factory MatchOfficial.fromJson(Map<String, dynamic> m) => MatchOfficial.fromMap(m);
}

class MatchLineupApproval {
  MatchLineupApproval({required this.id, required this.matchId,
    required this.participantId, required this.side,
    required List<String> starterAthleteIds, required List<String> substituteAthleteIds,
    required this.verifiedBy, required this.verifiedAt, required this.isLocked,
    this.notes}) : starterAthleteIds = List.unmodifiable(starterAthleteIds),
      substituteAthleteIds = List.unmodifiable(substituteAthleteIds);
  final String id;
  final String matchId;
  final String participantId;
  final MatchLineupSide side;
  final List<String> starterAthleteIds;
  final List<String> substituteAthleteIds;
  // FK ON DELETE SET NULL preserves the approval when its author is removed.
  final String? verifiedBy;
  final DateTime verifiedAt;
  final bool isLocked;
  final String? notes;
  factory MatchLineupApproval.fromMap(Map<String, dynamic> m) => MatchLineupApproval(
    id: m['id'] as String, matchId: m['match_id'] as String,
    participantId: m['participant_id'] as String,
    side: _decode(MatchLineupSide.values, (v) => v.name, m['side']),
    starterAthleteIds: (m['starter_athlete_ids'] as List).cast<String>(),
    substituteAthleteIds: (m['substitute_athlete_ids'] as List).cast<String>(),
    verifiedBy: m['verified_by'] as String?, verifiedAt: _date(m, 'verified_at'),
    isLocked: m['is_locked'] as bool, notes: m['notes'] as String?);
  factory MatchLineupApproval.fromJson(Map<String, dynamic> m) => MatchLineupApproval.fromMap(m);
}

class ClubStaffRole {
  const ClubStaffRole({required this.id, required this.clubId,
    required this.profileId, required this.role, required this.assignedAt});
  final String id;
  final String clubId;
  final String profileId;
  final ClubStaffRoleKind role;
  final DateTime assignedAt;
  factory ClubStaffRole.fromMap(Map<String, dynamic> m) => ClubStaffRole(
    id: m['id'] as String, clubId: m['club_id'] as String,
    profileId: m['profile_id'] as String,
    role: _decode(ClubStaffRoleKind.values, (v) => v.wireName, m['role']),
    assignedAt: _date(m, 'assigned_at'));
  factory ClubStaffRole.fromJson(Map<String, dynamic> m) => ClubStaffRole.fromMap(m);
}

/// Own assignment only; the public accepted-official card is deliberately separate.
class RefereeMatchSummary {
  const RefereeMatchSummary({required this.officialId, required this.matchId,
    required this.duty, required this.status, required this.assignedAt,
    this.startsAt, this.location, required this.sportCode,
    this.homeClubName, this.awayClubName, this.declineReason,
    this.matchStatus = 'scheduled', this.cityCode});
  final String officialId;
  final String matchId;
  final MatchOfficialDuty duty;
  final MatchOfficialStatus status;
  final DateTime assignedAt;
  final DateTime? startsAt;
  final String? location;
  final String sportCode;
  final String? homeClubName;
  final String? awayClubName;
  final String? declineReason;
  final String matchStatus;
  final String? cityCode;
  bool get canControl => status == MatchOfficialStatus.accepted &&
    (duty == MatchOfficialDuty.headReferee || duty == MatchOfficialDuty.tableOfficial);
  factory RefereeMatchSummary.fromMap(Map<String, dynamic> m) => RefereeMatchSummary(
    officialId: m['official_id'] as String, matchId: m['match_id'] as String,
    duty: _decode(MatchOfficialDuty.values, (v) => v.wireName, m['duty']),
    status: _decode(MatchOfficialStatus.values, (v) => v.name, m['status']),
    assignedAt: _date(m, 'assigned_at'), startsAt: _optionalDate(m, 'starts_at'),
    location: m['location'] as String?, sportCode: m['sport_code'] as String,
    homeClubName: m['home_club_name'] as String?, awayClubName: m['away_club_name'] as String?,
    declineReason: m['decline_reason'] as String?,
    matchStatus: m['match_status'] as String? ?? 'scheduled', cityCode: m['city_code'] as String?);
  factory RefereeMatchSummary.fromJson(Map<String, dynamic> m) => RefereeMatchSummary.fromMap(m);
}

class AcceptedMatchOfficial {
  const AcceptedMatchOfficial({required this.name, required this.duty});
  final String name;
  final MatchOfficialDuty duty;
  factory AcceptedMatchOfficial.fromMap(Map<String, dynamic> m) => AcceptedMatchOfficial(
    name: m['name'] as String,
    duty: _decode(MatchOfficialDuty.values, (v) => v.wireName, m['duty']));
  factory AcceptedMatchOfficial.fromJson(Map<String, dynamic> m) => AcceptedMatchOfficial.fromMap(m);
}

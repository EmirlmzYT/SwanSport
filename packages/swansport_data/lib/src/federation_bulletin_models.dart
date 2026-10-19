/// Federasyon disiplin bülteni ve resmi duyuru veri modelleri.
class FederationDisciplinaryItem {
  const FederationDisciplinaryItem({
    required this.id,
    required this.matchId,
    required this.sportCode,
    required this.clubName,
    required this.athleteDisplay,
    required this.penaltyType,
    required this.penaltyLabel,
    required this.reason,
    required this.createdAt,
    required this.matchTitle,
    required this.programName,
    this.cityCode,
  });

  final String id;
  final String matchId;
  final String sportCode;
  final String? cityCode;
  final String clubName;
  final String athleteDisplay;
  final String penaltyType; // 'match_ban', 'rights_ban', 'warning', 'fine'
  final String penaltyLabel;
  final String reason;
  final DateTime createdAt;
  final String matchTitle;
  final String programName;

  bool get isSuspension =>
      penaltyType == 'match_ban' || penaltyType == 'rights_ban';
  bool get isWarning => penaltyType == 'warning';
  bool get isFine => penaltyType == 'fine';

  factory FederationDisciplinaryItem.fromMap(Map<String, dynamic> map) {
    return FederationDisciplinaryItem(
      id: map['id'] as String,
      matchId: map['match_id'] as String,
      sportCode: map['sport_code'] as String,
      cityCode: map['city_code'] as String?,
      clubName: map['club_name'] as String? ?? 'Kulüp',
      athleteDisplay: map['athlete_display'] as String? ?? 'Sporcu',
      penaltyType: map['penalty_type'] as String? ?? 'warning',
      penaltyLabel: map['penalty_label'] as String? ?? 'Disiplin Kararı',
      reason: map['reason'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      matchTitle: map['match_title'] as String? ?? '',
      programName: map['program_name'] as String? ?? '',
    );
  }
}

class FederationNoticeItem {
  const FederationNoticeItem({
    required this.id,
    required this.sportCode,
    required this.noticeType,
    required this.title,
    required this.body,
    required this.publishedAt,
    required this.programName,
    this.cityCode,
    this.matchId,
  });

  final String id;
  final String sportCode;
  final String? cityCode;
  final String noticeType; // 'match_cancelled', 'match_postponed', 'status_update'
  final String title;
  final String body;
  final DateTime publishedAt;
  final String programName;
  final String? matchId;

  bool get isCancellation => noticeType == 'match_cancelled';
  bool get isPostponement => noticeType == 'match_postponed';

  factory FederationNoticeItem.fromMap(Map<String, dynamic> map) {
    return FederationNoticeItem(
      id: map['id'] as String,
      sportCode: map['sport_code'] as String,
      cityCode: map['city_code'] as String?,
      noticeType: map['notice_type'] as String? ?? 'status_update',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      publishedAt: DateTime.parse(map['published_at'] as String),
      programName: map['program_name'] as String? ?? '',
      matchId: map['match_id'] as String?,
    );
  }
}

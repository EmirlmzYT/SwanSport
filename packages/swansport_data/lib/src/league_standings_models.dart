class LeagueStandingsRow {
  LeagueStandingsRow({required this.rank,required this.participantId,required this.name,
    this.clubId,this.clubName,this.clubLogo,required this.played,required this.won,
    required this.drawn,required this.lost,required this.goalsFor,required this.goalsAgainst,
    required this.goalDiff,required this.points,List<String> form=const [],this.isProvisional=false})
    : form=List.unmodifiable(form);
  final int rank,played,won,drawn,lost,goalsFor,goalsAgainst,goalDiff,points;
  final String participantId,name;
  final String? clubId,clubName,clubLogo;
  final List<String> form;
  final bool isProvisional;
  factory LeagueStandingsRow.fromMap(Map<String,dynamic> m) => LeagueStandingsRow(
    rank:(m['rank'] as num).toInt(),participantId:m['participant_id'] as String,
    name:m['participant_name'] as String,clubId:m['club_id'] as String?,clubName:m['club_name'] as String?,
    clubLogo:m['club_logo'] as String?,played:(m['played'] as num).toInt(),won:(m['won'] as num).toInt(),
    drawn:(m['drawn'] as num).toInt(),lost:(m['lost'] as num).toInt(),goalsFor:(m['goals_for'] as num).toInt(),
    goalsAgainst:(m['goals_against'] as num).toInt(),goalDiff:(m['goal_diff'] as num).toInt(),points:(m['points'] as num).toInt(),
    form:[for(final value in m['form'] as List<Object?>? ?? const []) if(const ['W','D','L'].contains(value)) value as String],
    isProvisional:m['is_provisional']==true);
}

class LeagueStandingsTable {
  LeagueStandingsTable({required this.orgId,required this.sportCode,required this.isLive,
    required List<LeagueStandingsRow> rows}) : rows=List.unmodifiable(rows);
  final String orgId,sportCode;
  /// Selected provisional mode, not proof that an actual match is live.
  final bool isLive;
  final List<LeagueStandingsRow> rows;
}

class StandingsLeague {
  const StandingsLeague({required this.id,required this.name,required this.sportCode,
    this.cityCode,this.federationId,this.winPoints=3,this.drawPoints=1,this.lossPoints=0});
  final String id,name,sportCode;
  final String? cityCode,federationId;
  final int winPoints,drawPoints,lossPoints;
  factory StandingsLeague.fromMap(Map<String,dynamic> m)=>StandingsLeague(
    id:m['id'] as String,name:m['name'] as String,sportCode:m['sport_code'] as String,
    cityCode:m['city_code'] as String?,federationId:m['federation_id'] as String?,winPoints:(m['win_points'] as num).toInt(),
    drawPoints:(m['draw_points'] as num).toInt(),lossPoints:(m['loss_points'] as num).toInt());
}

class MatchStandingsContext {
  const MatchStandingsContext({required this.orgId,required this.name,required this.sportCode,
    this.homeParticipantId,this.awayParticipantId});
  final String orgId,name,sportCode;
  final String? homeParticipantId,awayParticipantId;
  factory MatchStandingsContext.fromMap(Map<String,dynamic> m)=>MatchStandingsContext(
    orgId:m['org_id'] as String,name:m['name'] as String,sportCode:m['sport_code'] as String,
    homeParticipantId:m['home_participant_id'] as String?,awayParticipantId:m['away_participant_id'] as String?);
}

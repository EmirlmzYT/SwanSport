import 'dart:math' show max;

bool isPublicMatchId(String value) => RegExp(
  r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',caseSensitive:false).hasMatch(value);
DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;
int? _int(Object? value) => value is num ? value.toInt() : null;

class PublicLiveMatchSummary {
  PublicLiveMatchSummary({required this.matchId,required this.sportCode,required this.status,
    this.cityCode,this.programName,this.startsAt,this.location,this.homeClubName,this.awayClubName,
    this.homeClubLogo,this.awayClubLogo,this.homeScore,this.awayScore,this.period,
    this.isLive=false,this.isToday=false,this.elapsedSeconds=0,this.clockStartedAt,this.serverNow,
    this.periodHome,this.periodAway,List<({int home,int away})> sets=const []}) : sets=List.unmodifiable(sets);
  final String matchId,sportCode,status;
  final String? cityCode,programName,location,homeClubName,awayClubName,homeClubLogo,awayClubLogo;
  final DateTime? startsAt,clockStartedAt,serverNow;
  final int? homeScore,awayScore,period,periodHome,periodAway;
  final bool isLive,isToday;
  final int elapsedSeconds;
  final List<({int home,int away})> sets;
  bool get clockRunning => isLive && clockStartedAt!=null && serverNow!=null;
  /// Server time anchors the snapshot; local monotonic duration only animates it.
  int secondsAt(Duration sinceSnapshot) => max(0,elapsedSeconds) + (clockRunning
    ? max(0,serverNow!.difference(clockStartedAt!).inSeconds)+max(0,sinceSnapshot.inSeconds) : 0);
  factory PublicLiveMatchSummary.fromMap(Map<String,dynamic> m) => PublicLiveMatchSummary(
    matchId:m['match_id'] as String,sportCode:m['sport_code'] as String,status:m['status'] as String,
    cityCode:m['city_code'] as String?,programName:m['program_name'] as String?,startsAt:_date(m['starts_at']),
    location:m['location'] as String?,homeClubName:m['home_club_name'] as String?,awayClubName:m['away_club_name'] as String?,
    homeClubLogo:m['home_club_logo'] as String?,awayClubLogo:m['away_club_logo'] as String?,
    homeScore:_int(m['home_score']),awayScore:_int(m['away_score']),period:_int(m['period']),
    periodHome:_int(m['period_home']),periodAway:_int(m['period_away']),
    isLive:m['is_live']==true,isToday:m['is_today']==true,elapsedSeconds:_int(m['elapsed_seconds'])??0,
    clockStartedAt:_date(m['clock_started_at']),serverNow:_date(m['server_now']),
    sets:[for(final row in m['sets'] as List? ?? const [])
      if(row is Map && row['home'] is num && row['away'] is num)
        (home:(row['home'] as num).toInt(),away:(row['away'] as num).toInt())]);
}

class PublicLiveMatchEvent {
  const PublicLiveMatchEvent({required this.sequence,required this.kind,this.side,this.card,
    this.athleteName,this.replacementName,this.minute=0,this.period=1});
  final int sequence,minute,period;
  final String kind;
  final String? side,card,athleteName,replacementName;
  factory PublicLiveMatchEvent.fromMap(Map<String,dynamic> m) => PublicLiveMatchEvent(
    sequence:_int(m['sequence'])??0,kind:m['kind'] as String,side:m['side'] as String?,card:m['card'] as String?,
    athleteName:m['athlete_name'] as String?,replacementName:m['replacement_name'] as String?,
    minute:_int(m['minute'])??0,period:_int(m['period'])??1);
}

class PublicLiveMatchDetail {
  PublicLiveMatchDetail({required this.summary,List<PublicLiveMatchEvent> events=const [],
    List<({String name,String duty})> officials=const []})
    : events=List.unmodifiable(events),officials=List.unmodifiable(officials);
  final PublicLiveMatchSummary summary;
  final List<PublicLiveMatchEvent> events;
  final List<({String name,String duty})> officials;
  factory PublicLiveMatchDetail.fromMap(Map<String,dynamic> m) => PublicLiveMatchDetail(
    summary:PublicLiveMatchSummary.fromMap(m),
    events:[for(final row in m['events'] as List? ?? const [])
      if(row is Map && const {'score','card','substitution','period_end'}.contains(row['kind']))
        PublicLiveMatchEvent.fromMap(Map<String,dynamic>.from(row))],
    officials:[for(final row in m['officials'] as List? ?? const [])
      if(row is Map && row['name'] is String && row['duty'] is String)
        (name:row['name'] as String,duty:row['duty'] as String)]);
}

class PublicRosterPlayer {
  const PublicRosterPlayer({required this.name,required this.side,required this.selection,this.jerseyNumber,this.position});
  final String name,side,selection;
  final String? jerseyNumber;
  final String? position;
  factory PublicRosterPlayer.fromMap(Map<String,dynamic> m) => PublicRosterPlayer(
    name:m['name'] as String? ?? 'sporcu',side:m['side'] as String,selection:m['selection'] as String,
    jerseyNumber:m['jersey_number']?.toString(),position:m['position'] as String?);
}
class PublicMatchRoster {
  PublicMatchRoster({required this.matchId,List<PublicRosterPlayer> players=const []}) : players=List.unmodifiable(players);
  final String matchId;
  final List<PublicRosterPlayer> players;
  factory PublicMatchRoster.fromMap(Map<String,dynamic> m) => PublicMatchRoster(matchId:m['match_id'] as String,
    players:[for(final row in m['players'] as List? ?? const []) PublicRosterPlayer.fromMap(Map<String,dynamic>.from(row as Map))]);
}

part of 'official_match_protocol.dart';

class BasketballPeriod {
  const BasketballPeriod(this.label, this.score, this.teamFouls);
  final String label;
  final TeamScore score;
  final TeamScore teamFouls;
}

class BasketballPlayerStats {
  const BasketballPlayerStats(
    this.playerRef,
    this.team,
    this.points,
    this.rebounds,
    this.assists,
    this.fouls,
  );
  final String playerRef;
  final String team;
  final int points, rebounds, assists, fouls;
}

class BasketballMatchProtocol extends OfficialMatchProtocol {
  BasketballMatchProtocol._(
    MatchStatus status,
    List<BasketballPeriod> periods,
    List<BasketballPlayerStats> players,
  )   : periods = List.unmodifiable(periods),
        players = List.unmodifiable(players),
        super('basketbol', status);
  final List<BasketballPeriod> periods;

  /// İsteğe bağlı, kısmi istatistik; takım skorunun yerine geçmez.
  final List<BasketballPlayerStats> players;
  TeamScore get score => _sum(periods.map((p) => p.score));
  MatchWinner get winner => isComplete ? score.leader : MatchWinner.undecided;
  bool get requiresOvertime =>
      !isComplete && periods.length >= 4 && score.leader == MatchWinner.draw;
}

BasketballMatchProtocol _basketball(
  Map<String, dynamic> raw,
  MatchStatus status,
) {
  final rows = _list(raw['periods'], 'periods');
  if (rows.isEmpty || (status == MatchStatus.finished && rows.length < 4)) {
    _fail('periods', 'En az bir periyot; bitmiş maçta dört çeyrek gerekli');
  }
  final periods = <BasketballPeriod>[];
  var total = const TeamScore(0, 0);
  for (var i = 0; i < rows.length; i++) {
    final path = 'periods[$i]';
    final row = _map(rows[i], path);
    final label = i < 4 ? 'Q${i + 1}' : 'OT${i - 3}';
    if (row['label'] != label) _fail('$path.label', '$label bekleniyor');
    if (i >= 4 && total.leader != MatchWinner.draw) {
      _fail(path, 'Uzatma yalnız önceki toplam eşitse oynanır');
    }
    final score = _score(row, path);
    periods.add(
      BasketballPeriod(
        label,
        score,
        _score(row['team_fouls'], '$path.team_fouls'),
      ),
    );
    total += score;
  }
  if (status == MatchStatus.finished && total.leader == MatchWinner.draw) {
    _fail('periods', 'Resmi basketbol maçı berabere bitemez; uzatma gerekli');
  }
  final players = <BasketballPlayerStats>[];
  final seen = <String>{};
  final stats = _list(raw['players'], 'players', optional: true);
  for (var i = 0; i < stats.length; i++) {
    final path = 'players[$i]';
    final row = _map(stats[i], path);
    final id = _text(row['player_ref'], '$path.player_ref');
    _unique(seen, id, '$path.player_ref');
    players.add(
      BasketballPlayerStats(
        id,
        _team(row['team'], '$path.team'),
        _integer(row['points'], '$path.points'),
        _integer(row['rebounds'], '$path.rebounds'),
        _integer(row['assists'], '$path.assists'),
        _integer(row['fouls'], '$path.fouls'),
      ),
    );
  }
  final playerScore = _sum(
    players.map(
      (p) => p.team == 'home' ? TeamScore(p.points, 0) : TeamScore(0, p.points),
    ),
  );
  final homePoints = playerScore.home;
  final awayPoints = playerScore.away;
  if (homePoints > total.home || awayPoints > total.away) {
    _fail('players', 'Oyuncu sayıları takım toplamını aşamaz');
  }
  return BasketballMatchProtocol._(status, periods, players);
}

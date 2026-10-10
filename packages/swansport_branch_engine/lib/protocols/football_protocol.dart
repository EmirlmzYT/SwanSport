part of 'official_match_protocol.dart';

class FootballEvent {
  const FootballEvent(
    this.minute,
    this.addedTime,
    this.playerRef,
    this.team, {
    this.card,
  });
  final int minute, addedTime;
  final String playerRef, team;
  final String? card;
}

class PenaltyKick {
  const PenaltyKick(this.team, this.scored);
  final String team;
  final bool scored;
}

class FootballMatchProtocol extends OfficialMatchProtocol {
  FootballMatchProtocol._(
    MatchStatus status,
    this.knockout,
    List<TeamScore> halves,
    List<TeamScore> extraTime,
    List<PenaltyKick> penalties,
    List<FootballEvent> goals,
    List<FootballEvent> cards,
    this.shootoutComplete,
  )   : halves = List.unmodifiable(halves),
        extraTime = List.unmodifiable(extraTime),
        penalties = List.unmodifiable(penalties),
        goals = List.unmodifiable(goals),
        cards = List.unmodifiable(cards),
        super('futbol', status);
  final bool knockout, shootoutComplete;
  final List<TeamScore> halves, extraTime;
  final List<PenaltyKick> penalties;
  final List<FootballEvent> goals, cards;

  /// Seri penaltılar maçtaki gol toplamına eklenmez.
  TeamScore get score => _sum([...halves, ...extraTime]);
  TeamScore get penaltyScore => TeamScore(
        penalties.where((p) => p.team == 'home' && p.scored).length,
        penalties.where((p) => p.team == 'away' && p.scored).length,
      );
  MatchWinner get winner => !isComplete
      ? MatchWinner.undecided
      : penalties.isNotEmpty
          ? penaltyScore.leader
          : score.leader;
}

FootballMatchProtocol _football(Map<String, dynamic> raw, MatchStatus status) {
  List<TeamScore> scores(String key, {bool optional = false}) {
    final rows = _list(raw[key], key, optional: optional);
    return [for (var i = 0; i < rows.length; i++) _score(rows[i], '$key[$i]')];
  }

  final halves = scores('halves');
  if (halves.isEmpty ||
      halves.length > 2 ||
      (status == MatchStatus.finished && halves.length != 2)) {
    _fail(
      'halves',
      'Bitmiş maçta iki; devam eden maçta bir veya iki devre gerekli',
    );
  }
  final extra = scores('extra_time', optional: true);
  final knockout = _boolean(raw['knockout'], 'knockout');
  final regular = _sum(halves);
  if (extra.length > 2 ||
      (status == MatchStatus.finished && extra.length == 1)) {
    _fail('extra_time', 'Bitmiş uzatma iki devre olmalı');
  }
  if (extra.isNotEmpty &&
      (!knockout || halves.length != 2 || regular.leader != MatchWinner.draw)) {
    _fail('extra_time', 'Uzatma için eleme maçı ve beraberlik gerekli');
  }
  final total = regular + _sum(extra);
  final kicks = <PenaltyKick>[];
  var home = 0, away = 0, homeAttempts = 0, awayAttempts = 0;
  var complete = false;
  final penalties = _list(raw['penalties'], 'penalties', optional: true);
  if (penalties.isNotEmpty &&
      (!knockout ||
          halves.length != 2 ||
          total.leader != MatchWinner.draw ||
          extra.length == 1)) {
    _fail(
      'penalties',
      'Seri penaltı için tamamlanmış, berabere eleme skoru gerekli',
    );
  }
  String? firstTeam;
  for (var i = 0; i < penalties.length; i++) {
    final path = 'penalties[$i]';
    if (complete) _fail(path, 'Seri sonuçlandıktan sonra atış eklenemez');
    final row = _map(penalties[i], path);
    final team = _team(row['team'], '$path.team');
    firstTeam ??= team;
    final expected =
        i.isEven ? firstTeam : (firstTeam == 'home' ? 'away' : 'home');
    if (team != expected) _fail('$path.team', 'Atışlar sırayla olmalı');
    if (row['scored'] is! bool) _fail('$path.scored', 'Boolean gerekli');
    final scored = row['scored'] == true;
    kicks.add(PenaltyKick(team, scored));
    if (team == 'home') {
      homeAttempts++;
      if (scored) home++;
    } else {
      awayAttempts++;
      if (scored) away++;
    }
    if (homeAttempts <= 5 && awayAttempts <= 5) {
      complete =
          home > away + (5 - awayAttempts) || away > home + (5 - homeAttempts);
    } else {
      complete = homeAttempts == awayAttempts && home != away;
    }
  }
  if (status == MatchStatus.finished &&
      knockout &&
      total.leader == MatchWinner.draw &&
      !complete) {
    _fail(
      'penalties',
      'Berabere eleme maçında sonuçlanmış seri penaltı gerekli',
    );
  }
  List<FootballEvent> events(String key, {required bool cards}) {
    final rows = _list(raw[key], key, optional: true);
    return [
      for (var i = 0; i < rows.length; i++)
        _footballEvent(
          _map(rows[i], '$key[$i]'),
          '$key[$i]',
          extra.isNotEmpty
              ? (extra.length == 1 ? 105 : 120)
              : (halves.length == 1 ? 45 : 90),
          cards: cards,
        ),
    ];
  }

  final goals = events('goals', cards: false);
  final cards = events('cards', cards: true);
  if (goals.where((g) => g.team == 'home').length > total.home ||
      goals.where((g) => g.team == 'away').length > total.away) {
    _fail('goals', 'Gol olayları maç skorunu aşamaz');
  }
  return FootballMatchProtocol._(
    status,
    knockout,
    halves,
    extra,
    kicks,
    goals,
    cards,
    complete,
  );
}

FootballEvent _footballEvent(
  Map<String, dynamic> row,
  String path,
  int maxMinute, {
  required bool cards,
}) {
  final card = cards ? _text(row['card'], '$path.card') : null;
  if (cards && card != 'yellow' && card != 'red') {
    _fail('$path.card', 'yellow veya red olmalı');
  }
  return FootballEvent(
    _integer(row['minute'], '$path.minute', min: 1, max: maxMinute),
    _integer(row['added_time'] ?? 0, '$path.added_time'),
    _text(row['player_ref'], '$path.player_ref'),
    _team(row['team'], '$path.team'),
    card: card,
  );
}

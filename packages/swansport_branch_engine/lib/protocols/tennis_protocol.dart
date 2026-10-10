part of 'official_match_protocol.dart';

class TennisSetScore {
  const TennisSetScore(
    this.games,
    this.tieBreak,
    this.tieBreakTarget,
    this.isComplete,
  );
  final TeamScore games;
  final TeamScore? tieBreak;
  final int tieBreakTarget;
  final bool isComplete;
  MatchWinner get winner => isComplete ? games.leader : MatchWinner.undecided;
}

class TennisMatchProtocol extends OfficialMatchProtocol {
  TennisMatchProtocol._(
    MatchStatus status,
    this.bestOf,
    List<TennisSetScore> sets,
    this.homeGameScore,
    this.awayGameScore,
  )   : sets = List.unmodifiable(sets),
        super('tenis', status);
  final int bestOf;
  final List<TennisSetScore> sets;
  final String? homeGameScore, awayGameScore;
  int get setsToWin => bestOf ~/ 2 + 1;
  TeamScore get setScore => TeamScore(
        sets.where((s) => s.winner == MatchWinner.home).length,
        sets.where((s) => s.winner == MatchWinner.away).length,
      );
  MatchWinner get winner =>
      isComplete ? setScore.leader : MatchWinner.undecided;
}

TennisMatchProtocol _tennis(Map<String, dynamic> raw, MatchStatus status) {
  final bestOf = _integer(raw['best_of'], 'best_of');
  if (bestOf != 3 && bestOf != 5) _fail('best_of', '3 veya 5 olmalı');
  final rows = _list(raw['sets'], 'sets');
  if (rows.isEmpty || rows.length > bestOf) {
    _fail('sets', '1..$bestOf set gerekli');
  }
  final sets = <TennisSetScore>[];
  var home = 0, away = 0;
  final toWin = bestOf ~/ 2 + 1;
  for (var i = 0; i < rows.length; i++) {
    final path = 'sets[$i]';
    if (home == toWin || away == toWin) {
      _fail(path, 'Maç kazanıldıktan sonra set eklenemez');
    }
    final row = _map(rows[i], path);
    final games = _score(row, path);
    final high = games.home > games.away ? games.home : games.away;
    final low = games.home < games.away ? games.home : games.away;
    if (high > 7 || (high == 7 && (low < 5 || low > 6))) {
      _fail(path, 'Standart tie-break setinde geçersiz oyun skoru');
    }
    final target =
        _integer(row['tie_break_target'] ?? 7, '$path.tie_break_target');
    if (target != 7 && target != 10) {
      _fail('$path.tie_break_target', '7 veya 10 olmalı');
    }
    final tb = row['tie_break'] == null
        ? null
        : _score(row['tie_break'], '$path.tie_break');
    var complete = (high == 6 && low <= 4) || (high == 7 && low == 5);
    if (tb != null) {
      if (!((high == 6 && low == 6) || (high == 7 && low == 6))) {
        _fail(
          '$path.tie_break',
          'Tie-break yalnız 6-6 veya 7-6 skorunda olabilir',
        );
      }
      final tbHigh = tb.home > tb.away ? tb.home : tb.away;
      final tbLow = tb.home < tb.away ? tb.home : tb.away;
      final tbWon = tbHigh >= target && tbHigh - tbLow >= 2;
      // Oyun biter bitmez durur; ör. 12-3 oynanmış bir tie-break olamaz.
      if (tbWon && tbHigh != (tbLow + 2 > target ? tbLow + 2 : target)) {
        _fail(
          '$path.tie_break',
          'Tie-break sonuçlandıktan sonra puan eklenmiş',
        );
      }
      if (high == 7 && (!tbWon || tb.leader != games.leader)) {
        _fail(
          '$path.tie_break',
          '7-6 set için uyumlu, kazanılmış tie-break gerekli',
        );
      }
      if (high == 6 && tbWon) {
        _fail(path, 'Kazanılan tie-break set skorunu 7-6 yapmalı');
      }
      complete = high == 7;
    } else if (high == 7 && low == 6) {
      _fail('$path.tie_break', '7-6 set için tie-break puanları gerekli');
    }
    if (!complete && (i != rows.length - 1 || status == MatchStatus.finished)) {
      _fail(path, 'Tamamlanmamış set son set olmalı; bitmiş maçta olamaz');
    }
    final set = TennisSetScore(games, tb, target, complete);
    sets.add(set);
    if (set.winner == MatchWinner.home) home++;
    if (set.winner == MatchWinner.away) away++;
  }
  final won = home == toWin || away == toWin;
  if ((status == MatchStatus.finished) != won) {
    _fail(
      'status',
      won
          ? 'Kazanılmış maç finished olmalı'
          : 'Maç bitmesi için $toWin set kazanılmalı',
    );
  }
  String? homeGame, awayGame;
  if (raw['game_score'] != null) {
    final game = _map(raw['game_score'], 'game_score');
    homeGame = _text(game['home'], 'game_score.home');
    awayGame = _text(game['away'], 'game_score.away');
    const valid = {'0', '15', '30', '40', 'AD'};
    if (!valid.contains(homeGame) ||
        !valid.contains(awayGame) ||
        (homeGame == 'AD' && awayGame != '40') ||
        (awayGame == 'AD' && homeGame != '40')) {
      _fail('game_score', 'Geçersiz avantajlı oyun puanı');
    }
    if (status == MatchStatus.finished ||
        sets.last.isComplete ||
        sets.last.tieBreak != null ||
        (sets.last.games.home == 6 && sets.last.games.away == 6)) {
      _fail(
        'game_score',
        'Normal oyun puanı yalnız devam eden normal oyunda bulunur',
      );
    }
  }
  return TennisMatchProtocol._(status, bestOf, sets, homeGame, awayGame);
}

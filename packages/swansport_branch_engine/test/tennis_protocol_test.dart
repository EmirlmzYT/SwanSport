import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';
import 'protocol_fixtures.dart';

void main() {
  const definition = TennisDefinition();
  for (final bestOf in [3, 5]) {
    test('best of $bestOf requires ${bestOf ~/ 2 + 1} sets to win', () {
      final p = definition.validateProtocol(tennis(bestOf: bestOf));
      expect(p.winner, MatchWinner.home);
      expect(p.setsToWin, bestOf ~/ 2 + 1);
      expect(p.setScore.home, bestOf ~/ 2 + 1);
    });
  }
  test('split sets and final away victory', () {
    final p = definition.validateProtocol(
      tennis()..['sets'] = [pair(6, 3), pair(3, 6), pair(5, 7)],
    );
    expect(p.winner, MatchWinner.away);
    expect(p.setScore.away, 2);
  });
  for (final target in [7, 10]) {
    test('$target point tie-break with extended two point margin', () {
      final p = definition.validateProtocol(
        tennis()
          ..['sets'] = [
            {
              ...pair(7, 6),
              'tie_break': pair(target + 2, target),
              'tie_break_target': target,
            },
            pair(6, 0),
          ],
      );
      expect(p.sets.first.tieBreak!.home, target + 2);
      expect(p.winner, MatchWinner.home);
    });
  }
  test('live tie-break stays undecided and can be tied', () {
    final p = definition.validateProtocol({
      'status': 'in_progress',
      'best_of': 3,
      'sets': [
        {...pair(6, 6), 'tie_break': pair(8, 8)},
      ],
    });
    expect(p.winner, MatchWinner.undecided);
    expect(p.sets.single.isComplete, isFalse);
  });
  test('advantage game points are retained', () {
    final p = definition.validateProtocol({
      'status': 'in_progress',
      'best_of': 3,
      'sets': [pair(3, 3)],
      'game_score': {'home': 'AD', 'away': '40'},
    });
    expect(p.homeGameScore, 'AD');
    expect(p.awayGameScore, '40');
  });
  final invalidSets = <List<Map<String, dynamic>>>[
    [pair(6, 5), pair(6, 0)],
    [pair(8, 6), pair(6, 0)],
    [pair(7, 7), pair(6, 0)],
    [pair(7, 0), pair(6, 0)],
    [pair(7, 6), pair(6, 0)],
    [
      {...pair(7, 6), 'tie_break': pair(7, 6)},
      pair(6, 0),
    ],
    [
      {...pair(7, 6), 'tie_break': pair(5, 7)},
      pair(6, 0),
    ],
    [
      {...pair(7, 6), 'tie_break': pair(12, 2)},
      pair(6, 0),
    ],
    [
      {...pair(6, 6), 'tie_break': pair(7, 5)},
      pair(6, 0),
    ],
    [pair(6, 0), pair(6, 0), pair(0, 6)],
    [pair(6, 4)],
  ];
  for (var i = 0; i < invalidSets.length; i++) {
    test('invalid set chronology or tie-break $i rejected', () {
      expect(
        () => definition.validateProtocol(tennis()..['sets'] = invalidSets[i]),
        throwsA(isA<ProtocolValidationException>()),
      );
    });
  }
  test('invalid game score and unsupported match format rejected', () {
    for (final game in [
      {'home': 'AD', 'away': 'AD'},
      {'home': 'AD', 'away': '30'},
      {'home': '50', 'away': '0'},
      {'home': 15, 'away': 0},
    ]) {
      expect(
        () => definition.validateProtocol({
          'status': 'in_progress',
          'best_of': 3,
          'sets': [pair(0, 0)],
          'game_score': game,
        }),
        throwsA(isA<ProtocolValidationException>()),
      );
    }
    expect(
      () => definition.validateProtocol(tennis()..['best_of'] = 4),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
}

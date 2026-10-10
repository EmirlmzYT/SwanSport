import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';
import 'protocol_fixtures.dart';

void main() {
  const definition = BasketballDefinition();
  test('four quarters determine winner and preserve fouls/statistics', () {
    final raw = basketball()
      ..['players'] = [
        {
          'player_ref': 'a',
          'team': 'home',
          'points': 25,
          'rebounds': 8,
          'assists': 6,
          'fouls': 4,
        },
      ];
    final p = definition.validateProtocol(raw);
    expect(p.score.home, 80);
    expect(p.score.away, 72);
    expect(p.winner, MatchWinner.home);
    expect(p.periods.first.teamFouls.home, 4);
    expect(p.players.single.rebounds, 8);
    expect(p.players.single.assists, 6);
    expect(p.players.single.fouls, 4);
    expect(definition.fields.map((f) => f.key), contains('players'));
  });
  test('finished tie requires overtime; live tie has no winner', () {
    expect(
      () => definition.validateProtocol(basketball(tied: true)),
      throwsA(isA<ProtocolValidationException>()),
    );
    final raw = basketball(tied: true)..['status'] = 'in_progress';
    final p = definition.validateProtocol(raw);
    expect(p.requiresOvertime, isTrue);
    expect(p.winner, MatchWinner.undecided);
  });
  test('multiple tied overtimes followed by away win', () {
    final raw = basketball(tied: true);
    (raw['periods'] as List<dynamic>).addAll([
      {'label': 'OT1', ...pair(5, 5), 'team_fouls': pair(2, 3)},
      {'label': 'OT2', ...pair(4, 7), 'team_fouls': pair(1, 2)},
    ]);
    final p = definition.validateProtocol(raw);
    expect(p.score.home, 89);
    expect(p.score.away, 92);
    expect(p.winner, MatchWinner.away);
    expect(p.requiresOvertime, isFalse);
  });
  test('overtime after untied regulation is rejected', () {
    final raw = basketball();
    (raw['periods'] as List<dynamic>)
        .add({'label': 'OT1', ...pair(1, 0), 'team_fouls': pair(0, 0)});
    expect(
      () => definition.validateProtocol(raw),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  test('period labels, missing quarters, fouls and malformed stats reject', () {
    final cases = <Map<String, dynamic>>[
      basketball()..['periods'] = <dynamic>[],
      basketball()
        ..['periods'] = [
          {'label': 'Q2', ...pair(1, 0)},
        ],
      basketball()
        ..['players'] = [
          {'player_ref': 'a', 'points': -1},
        ],
    ];
    final missingFouls = basketball();
    ((missingFouls['periods'] as List<dynamic>)[0] as Map<String, dynamic>)
        .remove('team_fouls');
    cases.add(missingFouls);
    for (final raw in cases) {
      expect(
        () => definition.validateProtocol(raw),
        throwsA(isA<ProtocolValidationException>()),
      );
    }
  });
  test('player totals cannot exceed team points or repeat a player', () {
    final stats = {
      'player_ref': 'a',
      'team': 'home',
      'points': 81,
      'rebounds': 0,
      'assists': 0,
      'fouls': 0,
    };
    expect(
      () => definition.validateProtocol(basketball()..['players'] = [stats]),
      throwsA(isA<ProtocolValidationException>()),
    );
    stats['points'] = 10;
    expect(
      () => definition
          .validateProtocol(basketball()..['players'] = [stats, stats]),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
}

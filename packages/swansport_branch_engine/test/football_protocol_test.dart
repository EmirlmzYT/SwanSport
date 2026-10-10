import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';
import 'protocol_fixtures.dart';

void main() {
  const definition = FootballDefinition();
  Map<String, dynamic> kick(String team, bool scored) =>
      {'team': team, 'scored': scored};
  test('league draw and regulation victory', () {
    expect(definition.validateProtocol(football()).winner, MatchWinner.draw);
    final raw = football()..['halves'] = [pair(0, 1), pair(0, 0)];
    expect(definition.validateProtocol(raw).winner, MatchWinner.away);
    raw['status'] = 'in_progress';
    expect(definition.validateProtocol(raw).winner, MatchWinner.undecided);
  });
  test('extra time goals determine knockout winner', () {
    final raw = football(knockout: true)
      ..['extra_time'] = [pair(1, 0), pair(0, 0)];
    final p = definition.validateProtocol(raw);
    expect(p.score.home, 2);
    expect(p.score.away, 1);
    expect(p.winner, MatchWinner.home);
  });
  test('early shootout win after six kicks is separate from match goals', () {
    final raw = football(knockout: true)
      ..['penalties'] = [
        for (var i = 0; i < 3; i++) ...[
          kick('home', true),
          kick('away', false),
        ],
      ];
    final p = definition.validateProtocol(raw);
    expect(p.score.home, 1);
    expect(p.penaltyScore.home, 3);
    expect(p.shootoutComplete, isTrue);
    expect(p.winner, MatchWinner.home);
  });
  test('sudden death waits for equal attempts, either team may start', () {
    final raw = football(knockout: true)
      ..['penalties'] = [
        for (var i = 0; i < 5; i++) ...[kick('away', true), kick('home', true)],
        kick('away', false),
        kick('home', true),
      ];
    expect(definition.validateProtocol(raw).penaltyScore.home, 6);
    expect(definition.validateProtocol(raw).winner, MatchWinner.home);
    (raw['penalties'] as List<dynamic>).removeLast();
    expect(
      () => definition.validateProtocol(raw),
      throwsA(isA<ProtocolValidationException>()),
    );
    raw['status'] = 'in_progress';
    expect(definition.validateProtocol(raw).shootoutComplete, isFalse);
  });
  test('stoppage-time goal and yellow/red cards retain player reference', () {
    final raw = football()
      ..['goals'] = [
        {'minute': 45, 'added_time': 3, 'player_ref': 'a', 'team': 'home'},
      ]
      ..['cards'] = [
        {'minute': 22, 'player_ref': 'a', 'team': 'home', 'card': 'yellow'},
        {'minute': 90, 'player_ref': 'b', 'team': 'away', 'card': 'red'},
      ];
    final p = definition.validateProtocol(raw);
    expect(p.goals.single.addedTime, 3);
    expect(p.goals.single.playerRef, 'a');
    expect(p.cards.last.card, 'red');
  });
  test('invalid extra time, unfinished shootout and impossible kicks reject',
      () {
    final cases = [
      football(knockout: true),
      football()..['extra_time'] = [pair(0, 0), pair(0, 0)],
      football(knockout: true)..['extra_time'] = [pair(0, 0)],
      football(knockout: true)
        ..['penalties'] = [kick('home', true), kick('home', false)],
      football(knockout: true)..['penalties'] = [kick('home', true)],
      football()..['halves'] = [pair(0, 0)],
      football()
        ..['cards'] = [
          {'minute': 30, 'player_ref': 'a', 'team': 'home', 'card': 'blue'},
        ],
    ];
    for (final raw in cases) {
      expect(
        () => definition.validateProtocol(raw),
        throwsA(isA<ProtocolValidationException>()),
      );
    }
  });
  test('no kicks after shootout has already been won', () {
    final raw = football(knockout: true)
      ..['penalties'] = [
        for (var i = 0; i < 3; i++) ...[
          kick('home', true),
          kick('away', false),
        ],
        kick('home', true),
      ];
    expect(
      () => definition.validateProtocol(raw),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
}

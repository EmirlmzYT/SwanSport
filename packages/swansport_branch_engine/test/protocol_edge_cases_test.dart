import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';

import 'protocol_fixtures.dart';

void main() {
  test('live basketball requires no winner and no premature overtime', () {
    final p = const BasketballDefinition().validateProtocol({
      'status': 'in_progress',
      'periods': [
        {'label': 'Q1', ...pair(10, 10), 'team_fouls': pair(0, 0)},
      ],
    });
    expect(p.requiresOvertime, isFalse);
    expect(p.winner, MatchWinner.undecided);
  });
  test('score aggregation cannot exceed JSON safe integer precision', () {
    final raw = basketball();
    for (final period in raw['periods'] as List<dynamic>) {
      (period as Map<String, dynamic>)['home'] = 9007199254740991;
    }
    expect(
      () => validateMatchProtocol('basketbol', raw),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  test('live tennis cannot reach 7-7 in a standard tie-break set', () {
    expect(
      () => validateMatchProtocol('tenis', {
        'status': 'in_progress',
        'best_of': 3,
        'sets': [pair(7, 7)],
      }),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  test('normal game score cannot be attached to a 6-6 tie-break', () {
    expect(
      () => validateMatchProtocol('tenis', {
        'status': 'in_progress',
        'best_of': 3,
        'sets': [pair(6, 6)],
        'game_score': {'home': '15', 'away': '0'},
      }),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  test('live race may contain pending lanes but has no declared winners', () {
    final p = validateMatchProtocol('yuzme', {
      'status': 'in_progress',
      'performances': [
        performance('a', 1, 10000, 1),
        performance('b', 2, null, null),
      ],
    }) as AthleticsSwimmingMatchProtocol;
    expect(p.winners, isEmpty);
  });
  test('slower athletics result cannot share a faster finisher rank', () {
    expect(
      () => validateMatchProtocol('atletizm', {
        'status': 'finished',
        'performances': [
          performance('a', 1, 10000, 2),
          performance('b', 2, 10000, 1),
          performance('c', 3, 11000, 2),
        ],
      }),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  test('DQ and knockout flags reject truthy strings', () {
    expect(
      () => validateMatchProtocol('yuzme', {
        'status': 'finished',
        'performances': [
          performance('a', 1, null, null)..['dq'] = 'true',
        ],
      }),
      throwsA(isA<ProtocolValidationException>()),
    );
    expect(
      () => validateMatchProtocol('futbol', football()..['knockout'] = 'true'),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  test('football event in an unplayed half rejects', () {
    expect(
      () => validateMatchProtocol('futbol', {
        'status': 'in_progress',
        'halves': [pair(1, 0)],
        'goals': [
          {'minute': 60, 'player_ref': 'a', 'team': 'home'},
        ],
      }),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
}

import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';
import 'protocol_fixtures.dart';

void main() {
  for (final sport in ['yuzme', 'atletizm']) {
    test('$sport official times, ranks, lanes and heat winners', () {
      final p = validateMatchProtocol(sport, race())
          as AthleticsSwimmingMatchProtocol;
      expect(p.performances.first.timeMs, 10000);
      expect(p.performances.last.rank, 2);
      expect(p.winners.single.athleteRef, 'a');
    });
    test('$sport DQ and DNF have no official time/rank', () {
      final p = validateMatchProtocol(sport, {
        'status': 'finished',
        'performances': [
          performance('a', 1, null, null, dq: true),
          performance('b', 2, null, null, dnf: true),
        ],
      }) as AthleticsSwimmingMatchProtocol;
      expect(p.winners, isEmpty);
      expect(p.performances.first.dq, isTrue);
      expect(p.performances.last.dnf, isTrue);
    });
  }
  test('minutes:seconds:hundredths are exact integer milliseconds', () {
    expect(parseOfficialTime('01:02.34'), 62340);
    expect(parseOfficialTime('01:02.345'), 62345);
    expect(formatOfficialTime(62345), '01:02.345');
    final raw = race();
    final rows = raw['performances'] as List<dynamic>;
    final first = rows[0] as Map<String, dynamic>;
    first.remove('time_ms');
    first['time'] = '00:10.00';
    expect(
      const AthleticsSwimmingDefinition.swimming()
          .validateProtocol(raw)
          .performances
          .first
          .timeMs,
      10000,
    );
  });
  for (final time in [
    '1:60.00',
    '1:2.00',
    '1:02.1',
    '-1:02.00',
    'NaN',
    '00:00.00',
    '9999999999999999999999999:00.00',
  ]) {
    test('invalid official time $time rejected', () {
      expect(
        () => parseOfficialTime(time),
        throwsA(isA<ProtocolValidationException>()),
      );
    });
  }
  test('equal swimming times share competition rank 1,1,3', () {
    final p = const AthleticsSwimmingDefinition.swimming().validateProtocol({
      'status': 'finished',
      'performances': [
        performance('a', 1, 10000, 1),
        performance('b', 2, 10000, 1),
        performance('c', 3, 11000, 3),
      ],
    });
    expect(p.winners, hasLength(2));
  });
  test('athletics photo finish may split equal published times', () {
    final raw = race();
    ((raw['performances'] as List<dynamic>)[1]
        as Map<String, dynamic>)['time_ms'] = 10000;
    expect(
      const AthleticsSwimmingDefinition.athletics()
          .validateProtocol(raw)
          .winners
          .single
          .athleteRef,
      'a',
    );
    expect(
      () => const AthleticsSwimmingDefinition.swimming().validateProtocol(raw),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  test('heats rank independently and may reuse lane numbers', () {
    final p = const AthleticsSwimmingDefinition.swimming().validateProtocol({
      'status': 'finished',
      'performances': [
        performance('a', 1, 10000, 1),
        performance('b', 1, 12000, 1, heat: 2),
      ],
    });
    expect(p.winners, hasLength(2));
  });
  final badRows = [
    [performance('a', 1, 11000, 1), performance('b', 2, 10000, 2)],
    [performance('a', 1, 10000, 2)],
    [performance('a', 1, 10000, 1), performance('b', 1, 11000, 2)],
    [performance('a', 1, 10000, 1), performance('a', 2, 11000, 2)],
    [performance('a', 0, 10000, 1)],
    [performance('a', 1, 10000, 1, dq: true)],
    [performance('a', 1, null, null, dq: true, dnf: true)],
    [performance('a', 1, null, null)],
    [performance('a', 1, -1, 1)],
    [performance('a', 1, 10000, 1)..['time'] = '00:11.00'],
  ];
  for (var i = 0; i < badRows.length; i++) {
    test('inconsistent race row/ranking $i rejected', () {
      expect(
        () => validateMatchProtocol('yuzme', {
          'status': 'finished',
          'performances': badRows[i],
        }),
        throwsA(isA<ProtocolValidationException>()),
      );
    });
  }
}

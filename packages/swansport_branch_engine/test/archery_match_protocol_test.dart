import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> row(String id, int lane, int rank, List<int> series) => {
        'athlete_ref': id,
        'lane': lane,
        'heat': 1,
        'rank': rank,
        'series': series,
      };
  test('archery official series aggregate with official tie-break ordering',
      () {
    final p = validateMatchProtocol('okculuk', {
      'status': 'finished',
      'performances': [
        row('a', 1, 1, [30, 29]),
        row('b', 2, 2, [30, 29]),
      ],
    }) as ArcheryMatchProtocol;
    expect(p.performances.first.total, 59);
    expect(p.performances.last.rank, 2);
    expect(p.isComplete, true);
    expect(() => p.performances.first.series.add(3), throwsUnsupportedError);
  });
  test('archery score/rank, series types, duplicate target and DQ fail safely',
      () {
    for (final rows in [
      [
        row('a', 1, 1, [20]),
        row('b', 2, 2, [30]),
      ],
      [
        row('a', 1, 2, [30]),
      ],
      [
        row('a', 1, 1, [361]),
      ],
      [
        row('a', 1, 1, [30]),
        row('b', 1, 2, [20]),
      ],
      [
        {
          ...row('a', 1, 1, [30]),
          'dq': true,
        }
      ],
      [
        {
          ...row('a', 1, 1, [30]),
          'series': ['30'],
        }
      ],
    ]) {
      expect(
        () => validateMatchProtocol(
          'okculuk',
          {'status': 'finished', 'performances': rows},
        ),
        throwsA(isA<ProtocolValidationException>()),
      );
    }
  });
  test('archery DQ has no rank and does not invent medal', () {
    final p = validateMatchProtocol('okculuk', {
      'status': 'finished',
      'performances': [
        {'athlete_ref': 'a', 'lane': 1, 'heat': 1, 'dq': true},
      ],
    }) as ArcheryMatchProtocol;
    expect(p.performances.single.rank, isNull);
    expect(p.performances.single.total, 0);
  });
}

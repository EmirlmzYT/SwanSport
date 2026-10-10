part of 'official_match_protocol.dart';

class ArcheryPerformance {
  ArcheryPerformance(
    this.athleteRef,
    this.lane,
    this.heat,
    List<int> series,
    this.rank,
    this.dq,
    this.dnf,
  ) : series = List.unmodifiable(series);
  final String athleteRef;
  final int lane, heat;
  final List<int> series;
  final int? rank;
  final bool dq, dnf;
  int get total => series.fold(0, (sum, value) => sum + value);
}

/// Resmi seri toplamları. Antrenman/ok başına puan sözleşmesini değiştirmez.
class ArcheryMatchProtocol extends OfficialMatchProtocol {
  ArcheryMatchProtocol._(MatchStatus status, List<ArcheryPerformance> rows)
      : performances = List.unmodifiable(rows),
        super('okculuk', status);
  final List<ArcheryPerformance> performances;
}

ArcheryMatchProtocol _archeryMatch(
  Map<String, dynamic> raw,
  MatchStatus status,
) {
  final rows = _list(raw['performances'], 'performances');
  if (rows.isEmpty || rows.length > 200) {
    _fail('performances', '1..200 kayıt gerekli');
  }
  final lanes = <String>{}, athletes = <String>{};
  final result = <ArcheryPerformance>[];
  for (var i = 0; i < rows.length; i++) {
    final path = 'performances[$i]';
    final row = _map(rows[i], path);
    final id = _text(row['athlete_ref'], '$path.athlete_ref');
    final lane = _integer(row['lane'], '$path.lane', min: 1);
    final heat = _integer(row['heat'], '$path.heat', min: 1);
    _unique(lanes, '$heat/$lane', '$path.lane');
    _unique(athletes, '$heat/$id', '$path.athlete_ref');
    final dq = _boolean(row['dq'], '$path.dq');
    final dnf = _boolean(row['dnf'], '$path.dnf');
    if (dq && dnf) _fail(path, 'DQ ve DNF birlikte olamaz');
    final rank = row['rank'] == null
        ? null
        : _integer(row['rank'], '$path.rank', min: 1);
    final series = [
      for (final value
          in _list(row['series'], '$path.series', optional: dq || dnf))
        _integer(value, '$path.series', max: 360),
    ];
    if (dq || dnf) {
      if (rank != null || series.isNotEmpty) {
        _fail(path, 'DQ/DNF derece taşıyamaz');
      }
    } else if (series.isEmpty ||
        series.length > 100 ||
        (status == MatchStatus.finished && rank == null)) {
      _fail(path, '1..100 seri puanı ve resmi sıra gerekli');
    }
    result.add(ArcheryPerformance(id, lane, heat, series, rank, dq, dnf));
  }
  if (status == MatchStatus.finished) {
    for (final heat in result.map((p) => p.heat).toSet()) {
      final finishers = result
          .where((p) => p.heat == heat && !p.dq && !p.dnf)
          .toList()
        ..sort((a, b) => a.rank!.compareTo(b.rank!));
      for (var i = 0; i < finishers.length; i++) {
        final p = finishers[i];
        final expected =
            i > 0 && p.rank == finishers[i - 1].rank ? p.rank : i + 1;
        if (p.rank != expected ||
            (i > 0 &&
                (p.total > finishers[i - 1].total ||
                    (p.rank == finishers[i - 1].rank &&
                        p.total != finishers[i - 1].total)))) {
          _fail('performances', 'Seri puanları ve resmi sıralama uyuşmuyor');
        }
      }
    }
  }
  return ArcheryMatchProtocol._(status, result);
}

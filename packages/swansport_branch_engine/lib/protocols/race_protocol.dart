part of 'official_match_protocol.dart';

/// Resmi verilmiş dereceyi taşır; kronometre/yuvarlama veya foto-finiş kararı vermez.
class RacePerformance {
  const RacePerformance(
    this.athleteRef,
    this.lane,
    this.heat,
    this.timeMs,
    this.rank,
    this.dq,
    this.dnf,
  );
  final String athleteRef;
  final int lane, heat;
  final int? timeMs, rank;
  final bool dq, dnf;
}

class AthleticsSwimmingMatchProtocol extends OfficialMatchProtocol {
  AthleticsSwimmingMatchProtocol._(
    super.sportCode,
    super.status,
    List<RacePerformance> performances,
  ) : performances = List.unmodifiable(performances);
  final List<RacePerformance> performances;

  /// Her serinin birincileri; farklı seriler tek yarış gibi sıralanmaz.
  List<RacePerformance> get winners => isComplete
      ? List.unmodifiable(
          performances.where((p) => p.rank == 1 && !p.dq && !p.dnf),
        )
      : const [];
}

/// mm:ss.cc veya mm:ss.mmm; kesir iki haneyse salise, üç haneyse milisaniye.
int parseOfficialTime(String raw) {
  final match = RegExp(r'^(\d+):([0-5]\d)\.(\d{2}|\d{3})$').firstMatch(raw);
  if (match == null) _fail('time', 'mm:ss.cc veya mm:ss.mmm biçimi gerekli');
  final minutes = int.tryParse(match.group(1)!);
  if (minutes == null || minutes > _maxInteger ~/ 60000) {
    _fail('time', 'Derece çok büyük');
  }
  final seconds = int.parse(match.group(2)!);
  final fraction = match.group(3)!;
  final value = minutes * 60000 +
      seconds * 1000 +
      int.parse(fraction) * (fraction.length == 2 ? 10 : 1);
  return _integer(value, 'time', min: 1);
}

String formatOfficialTime(int milliseconds) {
  _integer(milliseconds, 'time_ms', min: 1);
  final minutes = milliseconds ~/ 60000;
  final seconds = (milliseconds ~/ 1000) % 60;
  final fraction = milliseconds % 1000;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}.'
      '${fraction.toString().padLeft(3, '0')}';
}

AthleticsSwimmingMatchProtocol _race(
  String sportCode,
  Map<String, dynamic> raw,
  MatchStatus status,
) {
  final rows = _list(raw['performances'], 'performances');
  if (rows.isEmpty) _fail('performances', 'En az bir kulvar kaydı gerekli');
  final performances = <RacePerformance>[];
  final lanes = <String>{}, athletes = <String>{};
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
    int? time;
    if (row['time_ms'] != null) {
      time = _integer(row['time_ms'], '$path.time_ms', min: 1);
    }
    if (row['time'] != null) {
      final parsed = parseOfficialTime(_text(row['time'], '$path.time'));
      if (time != null && time != parsed) {
        _fail(path, 'time ve time_ms uyuşmuyor');
      }
      time = parsed;
    }
    final rank = row['rank'] == null
        ? null
        : _integer(row['rank'], '$path.rank', min: 1);
    if ((dq || dnf) && (time != null || rank != null)) {
      _fail(path, 'DQ/DNF kaydına resmi derece veya sıralama verilemez');
    }
    if (!dq &&
        !dnf &&
        status == MatchStatus.finished &&
        (time == null || rank == null)) {
      _fail(path, 'Bitiren sporcu için derece ve rank gerekli');
    }
    if ((rank != null && time == null) || (time != null && rank == null)) {
      _fail(path, 'Derece ve rank birlikte verilmeli');
    }
    performances.add(RacePerformance(id, lane, heat, time, rank, dq, dnf));
  }
  for (final heat in performances.map((p) => p.heat).toSet()) {
    final finishers =
        performances.where((p) => p.heat == heat && p.timeMs != null).toList()
          ..sort((a, b) {
            final timeOrder = a.timeMs!.compareTo(b.timeMs!);
            return timeOrder != 0 ? timeOrder : a.rank!.compareTo(b.rank!);
          });
    for (var i = 0; i < finishers.length; i++) {
      final p = finishers[i];
      if (i > 0 && p.timeMs == finishers[i - 1].timeMs) {
        // Yüzmede eşit resmi dereceler eşit sıralanır. Atletizmde foto-finiş
        // aynı yayımlanan dereceyi ayırabilir; rank hakemden gelir.
        if (sportCode == 'yuzme' && p.rank != finishers[i - 1].rank) {
          _fail('performances', 'Aynı yüzme derecesi aynı rank olmalı');
        }
      } else if (i > 0 && p.rank! <= finishers[i - 1].rank!) {
        _fail('performances', 'Daha yavaş derece daha iyi/eşit rank alamaz');
      }
      if (p.rank! > finishers.length) {
        _fail('performances', 'Rank seri boyutunu aşamaz');
      }
    }
    // Birinci zorunlu, sıralar 1,2,3 veya beraberlikte 1,1,3 biçiminde.
    final byRank = [...finishers]..sort((a, b) => a.rank!.compareTo(b.rank!));
    for (var i = 0; i < byRank.length; i++) {
      final rank = byRank[i].rank!;
      final expected =
          i > 0 && rank == byRank[i - 1].rank ? byRank[i - 1].rank! : i + 1;
      if (rank != expected) _fail('performances', 'Tutarsız seri sıralaması');
    }
  }
  return AthleticsSwimmingMatchProtocol._(sportCode, status, performances);
}

/// Yerel müsabaka doğrulaması; federasyon yetkisi veya sunucu onayı vermez.
library;

part 'basketball_protocol.dart';
part 'football_protocol.dart';
part 'tennis_protocol.dart';
part 'race_protocol.dart';

enum MatchStatus { inProgress, finished }

enum MatchWinner { home, away, draw, undecided }

class ProtocolValidationException implements Exception {
  ProtocolValidationException(String path, String message)
      : errors = List.unmodifiable(['$path: $message']);
  final List<String> errors;
  @override
  String toString() => 'ProtocolValidationException: ${errors.join('; ')}';
}

abstract class OfficialMatchProtocol {
  const OfficialMatchProtocol(this.sportCode, this.status);
  final String sportCode;
  final MatchStatus status;
  bool get isComplete => status == MatchStatus.finished;
}

/// Sayılar tamsayı olmalı; eksik skor asla sıfıra çevrilmez.
OfficialMatchProtocol validateMatchProtocol(
  String sportCode,
  Map<String, dynamic> rawProtocol,
) {
  final declared = rawProtocol['sport_code'];
  if (declared != null && declared != sportCode) {
    _fail('sport_code', 'İstenen branşla uyuşmuyor');
  }
  final status = switch (rawProtocol['status']) {
    'in_progress' => MatchStatus.inProgress,
    'finished' => MatchStatus.finished,
    _ => _fail('status', 'in_progress veya finished olmalı'),
  };
  return switch (sportCode) {
    'basketbol' => _basketball(rawProtocol, status),
    'futbol' => _football(rawProtocol, status),
    'tenis' => _tennis(rawProtocol, status),
    'yuzme' || 'atletizm' => _race(sportCode, rawProtocol, status),
    _ => _fail('sport_code', 'Desteklenmeyen müsabaka branşı: $sportCode'),
  };
}

class TeamScore {
  const TeamScore(this.home, this.away);
  final int home;
  final int away;
  MatchWinner get leader => home == away
      ? MatchWinner.draw
      : home > away
          ? MatchWinner.home
          : MatchWinner.away;
  TeamScore operator +(TeamScore other) => TeamScore(
        _integer(home + other.home, 'score.home'),
        _integer(away + other.away, 'score.away'),
      );
}

Never _fail(String path, String message) =>
    throw ProtocolValidationException(path, message);

// Platformlar arası JSON tamsayı kesinliği (Dart VM ve dart2js).
const _maxInteger = 9007199254740991;
int _integer(Object? value, String path, {int min = 0, int max = _maxInteger}) {
  if (value is! int || value < min || value > max) {
    _fail(path, '$min..$max aralığında tamsayı olmalı');
  }
  return value;
}

String _text(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    _fail(path, 'Boş olmayan metin olmalı');
  }
  return value;
}

bool _boolean(Object? value, String path, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is! bool) _fail(path, 'Boolean olmalı');
  return value;
}

Map<String, dynamic> _map(Object? value, String path) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    _fail(path, 'Metin anahtarlı nesne olmalı');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(Object? value, String path, {bool optional = false}) {
  if (value == null && optional) return const [];
  if (value is! List) _fail(path, 'Liste olmalı');
  return value;
}

TeamScore _score(Object? value, String path) {
  final m = _map(value, path);
  return TeamScore(
    _integer(m['home'], '$path.home'),
    _integer(m['away'], '$path.away'),
  );
}

String _team(Object? value, String path) {
  if (value != 'home' && value != 'away') _fail(path, 'home veya away olmalı');
  return value as String;
}

TeamScore _sum(Iterable<TeamScore> scores) =>
    scores.fold(const TeamScore(0, 0), (sum, score) => sum + score);

void _unique(Set<String> seen, String key, String path) {
  if (!seen.add(key)) _fail(path, 'Tekrarlanan kayıt');
}

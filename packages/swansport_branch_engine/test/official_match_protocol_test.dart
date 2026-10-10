import 'dart:io';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';
import 'protocol_fixtures.dart';

void main() {
  test('registry preserves archery contract and adds five sports', () {
    expect(branchByCode('okculuk'), isA<ArcheryDefinition>());
    expect(const ArcheryDefinition().unitLabel, 'ok');
    expect(branchByCode('basketbol'), isA<BasketballDefinition>());
    expect(branchByCode('futbol'), isA<FootballDefinition>());
    expect(branchByCode('tenis'), isA<TennisDefinition>());
    expect(branchByCode('yuzme')!.displayName, 'Yüzme');
    expect(branchByCode('atletizm')!.displayName, 'Atletizm');
    expect(branchByCode(null), isNull);
    expect(branchByCode('unknown'), isNull);
    expect(
      kBranchDefinitions.map((d) => d.code).toSet().length,
      kBranchDefinitions.length,
    );
  });
  final fixtures = {
    'basketbol': basketball,
    'futbol': football,
    'tenis': tennis,
    'yuzme': race,
    'atletizm': race,
  };
  for (final entry in fixtures.entries) {
    test('${entry.key} missing required schema has a useful path', () {
      expect(
        () => validateMatchProtocol(entry.key, {'status': 'finished'}),
        throwsA(
          isA<ProtocolValidationException>()
              .having((e) => e.errors, 'errors', isNotEmpty),
        ),
      );
    });
    test('${entry.key} unknown/mismatched sport and invalid status reject', () {
      expect(
        () => validateMatchProtocol(
          entry.key,
          entry.value()..['sport_code'] = 'x',
        ),
        throwsA(isA<ProtocolValidationException>()),
      );
      expect(
        () => validateMatchProtocol(
          entry.key,
          entry.value()..['status'] = true,
        ),
        throwsA(isA<ProtocolValidationException>()),
      );
    });
  }
  test('unknown sports never silently fall back to another protocol', () {
    expect(
      () => validateMatchProtocol('unknown', basketball()),
      throwsA(isA<ProtocolValidationException>()),
    );
    expect(
      () => validateMatchProtocol('okculuk', basketball()),
      throwsA(isA<ProtocolValidationException>()),
    );
  });
  for (final bad in [
    null,
    '20',
    true,
    20.5,
    double.nan,
    double.infinity,
    -1,
    9007199254740992,
    <String, dynamic>{},
    <dynamic>[],
  ]) {
    test(
        'malformed score ${bad.runtimeType}/$bad has validation error, not cast error',
        () {
      final raw = basketball();
      ((raw['periods'] as List<dynamic>)[0] as Map<String, dynamic>)['home'] =
          bad;
      expect(
        () => validateMatchProtocol('basketbol', raw),
        throwsA(isA<ProtocolValidationException>()),
      );
    });
  }
  test('nested malformed JSON is rejected without TypeError', () {
    for (final value in [
      null,
      true,
      1,
      'x',
      [true],
      [
        <int, Object?>{1: 0},
      ]
    ]) {
      expect(
        () => validateMatchProtocol('tenis', tennis()..['sets'] = value),
        throwsA(isA<ProtocolValidationException>()),
      );
    }
  });
  test('parsed models snapshot inputs and expose immutable collections', () {
    final raw = basketball();
    final p =
        validateMatchProtocol('basketbol', raw) as BasketballMatchProtocol;
    ((raw['periods'] as List<dynamic>)[0] as Map<String, dynamic>)['home'] =
        999;
    expect(p.score.home, 80);
    expect(() => p.periods.clear(), throwsUnsupportedError);
  });
  test(
    'package production source and manifest remain pure Dart',
    () {
      final manifest = File('pubspec.yaml').readAsStringSync();
      expect(manifest, isNot(contains('flutter:')));
      expect(manifest, isNot(contains('supabase')));
      for (final file
          in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        expect(source, isNot(contains("'package:flutter/")), reason: file.path);
        expect(source, isNot(contains("'package:supabase")), reason: file.path);
      }
    },
    testOn: 'vm',
  );
}

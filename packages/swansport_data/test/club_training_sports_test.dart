import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('mutation preserves club scope and invalidates only after successful save', () async {
    final events = <String>[];
    final service = ClubTrainingSportsService((club, codes) async {
      events.add(club);
      expect(codes, ['yuzme', 'tenis']);
      expect(() => codes.add('futbol'), throwsUnsupportedError);
      return 2;
    }, () => events.add('invalidate'));
    expect(await service.setClubTrainingSports(clubId: 'club', sportCodes: ['yuzme', 'tenis']), 2);
    expect(events, ['club', 'invalidate']);
  });
  test('failure keeps selection and does not publish a successful refresh', () async {
    var invalidated = false;
    final service = ClubTrainingSportsService((_, __) async => throw StateError('denied'),
      () => invalidated = true);
    await expectLater(service.setClubTrainingSports(clubId: 'club', sportCodes: ['yuzme']), throwsStateError);
    expect(invalidated, isFalse);
  });
}

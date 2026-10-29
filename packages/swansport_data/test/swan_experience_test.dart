import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('Swan ID parses multiple verified roles without exposing private data', () {
    final card = SwanIdCard.fromMap({
      'public_code': 'SWN-ABC1234567',
      'full_name': 'Deniz Kuğu',
      'visibility': 'members',
      'is_minor': false,
      'roles': [
        {'kind': 'athlete_licensed', 'sport_code': 'basketbol'},
        {'kind': 'coach', 'sport_code': 'basketbol', 'coach_level': 2},
      ],
      'clubs': [
        {'name': 'Swan Gençlik', 'role': 'athlete'},
      ],
    });

    expect(card.publicCode, 'SWN-ABC1234567');
    expect(card.roles, hasLength(2));
    expect(card.roles.last.coachLevel, 2);
    expect(card.clubs.single['name'], 'Swan Gençlik');
  });

  test('public Swan ID token route is narrowly guest accessible', () {
    expect(
      SwanAccess.isGuestRoute(
        '/swan-id/dogrula/0123456789abcdef0123456789abcdef0123456789abcdef',
      ),
      isTrue,
    );
    expect(SwanAccess.isGuestRoute('/swan-id/dogrula/short'), isFalse);
    expect(SwanAccess.isGuestRoute('/swan-id'), isFalse);
  });

  test('match card keeps unknown lineup explicit', () {
    const card = AthleteMatchCard({
      'match_id': 'm1',
      'program_name': 'İl Ligi',
      'lineup_status': 'not_shared',
      'is_live': false,
    });
    expect(card.lineupStatus, 'not_shared');
    expect(card.isLive, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('0110 role activity derives from dates/revocation, not a missing SQL column', () {
    final role = FederationRole.fromJson({'id':'r', 'federation_id':'f',
      'profile_id':'p', 'role':'provincial_rep', 'city_code':'34',
      'starts_on':'2026-10-13', 'ends_on':'2026-10-13', 'revoked_at':null});
    expect(role.role, FederationRoleKind.provincialRep);
    expect(role.isActiveOn(DateTime.utc(2026,10,13,12)), isTrue);
    expect(role.isActiveOn(DateTime.utc(2026,10,14,12)), isFalse);
  });
  test('referee profile uses exact enum wire names', () {
    final profile = RefereeProfile.fromJson({'id':'r', 'profile_id':'p',
      'license_number':'R1', 'badge_tier':'international', 'sport_code':'tenis',
      'city_code':'34', 'is_active':true});
    expect(profile.badgeTier, RefereeBadgeTier.international);
    expect(profile.isActive, isTrue);
  });
  test('own assignment preserves reason and nullable response timestamp', () {
    final official = MatchOfficial.fromJson({'id':'o','match_id':'m','profile_id':'p',
      'duty':'assistant_referee_1','status':'declined','decline_reason':'Cannot attend',
      'assigned_at':'2026-10-13T00:00:00Z','responded_at':null});
    expect(official.duty, MatchOfficialDuty.assistantReferee1);
    expect(official.status, MatchOfficialStatus.declined);
    expect(official.declineReason, 'Cannot attend');
    expect(official.respondedAt, isNull);
  });
  test('approved roster arrays are defensive copies; author deletion remains nullable', () {
    final starters = ['a'];
    final approval = MatchLineupApproval.fromJson({'id':'l','match_id':'m',
      'participant_id':'p','side':'away','starter_athlete_ids':starters,
      'substitute_athlete_ids':['b'],'verified_by':null,
      'verified_at':'2026-10-13T00:00:00Z','is_locked':true,'notes':'Signed'});
    starters.add('c');
    expect(approval.starterAthleteIds, ['a']);
    expect(() => approval.starterAthleteIds.add('x'), throwsUnsupportedError);
    expect(() => approval.substituteAthleteIds.clear(), throwsUnsupportedError);
    expect(approval.side, MatchLineupSide.away);
    expect(approval.verifiedBy, isNull);
  });
  test('unknown duty fails closed; public model does not retain private input fields', () {
    expect(() => AcceptedMatchOfficial.fromMap({'name':'Referee','duty':'administrator'}), throwsFormatException);
    final card = AcceptedMatchOfficial.fromJson({'name':'Referee','duty':'table_official',
      'decline_reason':'private','national_id':'private','guardian_phone':'private'});
    expect(card.name, 'Referee');
    expect(card.duty, MatchOfficialDuty.tableOfficial);
  });
  test('match summary and club role deserialize their actual SQL outputs', () {
    final summary = RefereeMatchSummary.fromJson({'official_id':'o','match_id':'m',
      'duty':'head_referee','status':'accepted','assigned_at':'2026-10-13T00:00:00Z',
      'starts_at':null,'location':null,'sport_code':'tenis',
      'home_club_name':null,'away_club_name':null,'decline_reason':null});
    expect(summary.startsAt, isNull);
    expect(summary.status, MatchOfficialStatus.accepted);
    final staff = ClubStaffRole.fromJson({'id':'s','club_id':'c','profile_id':'p',
      'role':'sporting_director','assigned_at':'2026-10-13T00:00:00Z'});
    expect(staff.role, ClubStaffRoleKind.sportingDirector);
  });
}

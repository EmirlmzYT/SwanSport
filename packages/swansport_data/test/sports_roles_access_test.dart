import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  final day = DateTime.utc(2026, 10, 13, 12);
  FederationRole role(FederationRoleKind kind,
          {String federation = 'tennis',
          String? city,
          DateTime? revoked,
          DateTime? starts,
          DateTime? ends}) =>
      FederationRole(
          id: 'role',
          federationId: federation,
          profileId: 'me',
          role: kind,
          cityCode: city,
          startsOn: starts ?? DateTime(2026),
          endsOn: ends ?? DateTime(2090),
          revokedAt: revoked);
  SwanAccess access(
          {List<FederationRole> roles = const [],
          List<ClubStaffRole> staff = const [],
          RefereeProfile? referee,
          Set<String> medical = const {},
          Set<String> administrative = const {},
          String? clubRole,
          int coachLevel = 0,
          Set<String> accountants = const {}}) =>
      SwanAccess(
          isPlatformAdmin: false,
          clubRole: clubRole,
          coachLevel: coachLevel,
          athleteKind: null,
          federationRoles: roles,
          clubStaffRoles: staff,
          refereeProfile: referee,
          medicalAuthorityClubIds: medical,
          administrativeStatusClubIds: administrative,
          accountantClubIds: accountants);
  ClubStaffRole staff(ClubStaffRoleKind kind) => ClubStaffRole(
      id: 's', clubId: 'club', profileId: 'me', role: kind, assignedAt: day);

  test(
      'president inherits province/committee/disciplinary visibility, not other federation or legacy writes',
      () {
    final a = access(roles: [role(FederationRoleKind.president)]);
    expect(a.canOpenFederationOperations, isTrue);
    expect(a.isFederationPresident, isTrue);
    expect(a.isProvincialRep('06', federationId: 'tennis', at: day), isTrue);
    expect(a.isProvincialRep('06', federationId: 'swim', at: day), isFalse);
    expect(a.isRefereeCommitteeMember, isTrue);
    expect(a.isDisciplinaryBoardMember, isTrue);
    expect(
        a.canWriteFederation('tenis', '06', FederationDuty.resultPublisher,
            at: day),
        isFalse);
  });
  test('province and federation scope are both required', () {
    final a =
        access(roles: [role(FederationRoleKind.provincialRep, city: '34')]);
    expect(a.isProvincialRep('34', federationId: 'tennis', at: day), isTrue);
    expect(a.isProvincialRep('06', federationId: 'tennis', at: day), isFalse);
    expect(a.isProvincialRep('34', federationId: 'swim', at: day), isFalse);
    expect(a.isRefereeCommitteeMember, isFalse);
  });
  test('revoked, future and expired roles cannot authorize', () {
    for (final r in [
      role(FederationRoleKind.president, revoked: day),
      role(FederationRoleKind.president, starts: DateTime(2027)),
      role(FederationRoleKind.president, ends: DateTime(2025))
    ]) {
      expect(access(roles: [r]).isProvincialRep('34', at: day), isFalse);
      expect(access(roles: [r]).canOpenFederationOperations, isFalse);
    }
  });
  test('inclusive Turkey date boundary does not depend on device timezone', () {
    final r = role(FederationRoleKind.president,
        starts: DateTime(2026, 10, 13), ends: DateTime(2026, 10, 13));
    expect(r.isActiveOn(DateTime.utc(2026, 10, 12, 21)), isTrue);
    expect(r.isActiveOn(DateTime.utc(2026, 10, 13, 20, 59, 59)), isTrue);
    expect(r.isActiveOn(DateTime.utc(2026, 10, 13, 21)), isFalse);
  });
  test(
      'doctorless coach/admin retains administrative rest independently of medical staff',
      () {
    for (final clubRole in ['coach', 'club_admin']) {
      final a =
          access(clubRole: clubRole, coachLevel: 3, administrative: {'club'});
      expect(a.isClubStaff, isTrue);
      expect(a.canManageAdministrativeStatus('club'), isTrue);
      expect(a.canManageAdministrativeStatus('other'), isFalse);
      expect(a.hasMedicalAuthority, isFalse);
    }
    expect(
        access(
            clubRole: 'coach',
            coachLevel: 3,
            administrative: {'club'},
            medical: {'club'}).canManageAdministrativeStatus('club'),
        isTrue);
  });
  test(
      'doctor/physiotherapist label alone grants no medical or sporting rights',
      () {
    for (final kind in [
      ClubStaffRoleKind.doctor,
      ClubStaffRoleKind.physiotherapist
    ]) {
      final a = access(staff: [staff(kind)]);
      expect(a.isClubDoctor('club'), isTrue);
      expect(a.isClubMedicalStaff('other'), isFalse);
      expect(a.hasMedicalAuthority, isFalse);
      expect(a.isClubStaff, isFalse);
      expect(a.canManageAdministrativeStatus('club'), isFalse);
    }
    final authorized = access(medical: {'club'});
    expect(authorized.hasMedicalAuthorityForClub('club'), isTrue);
    expect(authorized.hasMedicalAuthorityForClub('other'), isFalse);
  });
  test('club specializations remain club scoped', () {
    final a = access(staff: [
      staff(ClubStaffRoleKind.president),
      staff(ClubStaffRoleKind.sportingDirector),
      staff(ClubStaffRoleKind.kitManager)
    ]);
    expect(a.isClubPresident('club'), isTrue);
    expect(a.isClubSportingDirector('club'), isTrue);
    expect(a.isClubKitManager('club'), isTrue);
    expect(a.isClubPresident('other'), isFalse);
  });
  test('accountant remains an independent axis with no sporting escalation',
      () {
    final a = access(accountants: {'club'});
    expect(a.isAccountant, isTrue);
    expect(a.isClubStaff, isFalse);
    expect(a.isReferee, isFalse);
    expect(a.isFederationPresident, isFalse);
    expect(a.hasMedicalAuthority, isFalse);
    expect(a.canManageAdministrativeStatus('club'), isFalse);
  });
  test('inactive referee and guest fail closed', () {
    expect(
        access(
                referee: const RefereeProfile(
                    id: 'r',
                    profileId: 'me',
                    licenseNumber: 'R1',
                    badgeTier: RefereeBadgeTier.national,
                    sportCode: 'tenis',
                    cityCode: '34',
                    isActive: false))
            .isReferee,
        isFalse);
    expect(SwanAccess.none.isReferee, isFalse);
    expect(SwanAccess.none.isFederationPresident, isFalse);
  });
  test(
      'SwanAccess consumes shared providers without an application-side role calculation',
      () async {
    final container = ProviderContainer(overrides: [
      currentProfileProvider.overrideWith(
          (ref) async => const ProfileInfo(id: 'me', fullName: 'Test')),
      myFederationRolesProvider
          .overrideWith((ref) async => [role(FederationRoleKind.president)]),
      myClubStaffRolesProvider
          .overrideWith((ref) async => [staff(ClubStaffRoleKind.kitManager)]),
      mySportsClubAuthorityProvider.overrideWith(
          (ref) async => SportsClubAuthority(medicalClubIds: {'club'})),
    ]);
    addTearDown(container.dispose);
    await container.read(currentProfileProvider.future);
    await container.read(myFederationRolesProvider.future);
    await container.read(myClubStaffRolesProvider.future);
    await container.read(mySportsClubAuthorityProvider.future);
    final a = container.read(swanAccessProvider);
    expect(a.isFederationPresident, isTrue);
    expect(a.isClubKitManager('club'), isTrue);
    expect(a.hasMedicalAuthorityForClub('club'), isTrue);
  });
}

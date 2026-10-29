import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/workspaces/pro_workspace.dart';

void main() {
  SwanAccess baseAccess({
    bool isPlatformAdmin = false,
    String? clubRole,
    int coachLevel = 0,
    String? athleteKind,
    Set<String> accountantClubIds = const {},
    Set<String> managedTurfFieldIds = const {},
    Set<String> delegatedTurfFieldIds = const {},
    List<FederationRole> federationRoles = const [],
    List<FederationAppointment> federationAppointments = const [],
    RefereeProfile? refereeProfile,
    List<ClubOperationsAuthority> clubOperationsAuthority = const [],
  }) {
    return SwanAccess(
      isPlatformAdmin: isPlatformAdmin,
      clubRole: clubRole,
      coachLevel: coachLevel,
      athleteKind: athleteKind,
      accountantClubIds: accountantClubIds,
      managedTurfFieldIds: managedTurfFieldIds,
      delegatedTurfFieldIds: delegatedTurfFieldIds,
      federationRoles: federationRoles,
      federationAppointments: federationAppointments,
      refereeProfile: refereeProfile,
      clubOperationsAuthority: clubOperationsAuthority,
    );
  }

  RefereeProfile fakeReferee({required bool isActive}) => RefereeProfile(
        id: 'ref-1',
        profileId: 'p-1',
        licenseNumber: 'LIC-100',
        badgeTier: RefereeBadgeTier.candidate,
        sportCode: 'football',
        cityCode: '34',
        isActive: isActive,
      );

  group('proWorkspacesFor', () {
    test('SwanAccess.none returns empty list', () {
      expect(proWorkspacesFor(SwanAccess.none), isEmpty);
    });

    test('active club staff roles map to ProWorkspace.club', () {
      for (final role in ['club_admin', 'coach', 'official']) {
        final access = baseAccess(clubRole: role);
        final workspaces = proWorkspacesFor(access);
        expect(workspaces.contains(ProWorkspace.club), isTrue,
            reason: 'Role $role should have club workspace');
      }

      final nonStaff = baseAccess(clubRole: 'member');
      expect(proWorkspacesFor(nonStaff).contains(ProWorkspace.club), isFalse);
    });

    test(
        'coachLevel > 0 without active staff membership maps to coaching but NOT club',
        () {
      final access = baseAccess(
        coachLevel: 2,
        clubRole: 'member',
      );
      final workspaces = proWorkspacesFor(access);
      expect(workspaces.contains(ProWorkspace.coaching), isTrue);
      expect(workspaces.contains(ProWorkspace.club), isFalse);
    });

    test('active club coach has both club and coaching workspaces', () {
      final access = baseAccess(
        coachLevel: 0,
        clubRole: 'coach',
      );
      final workspaces = proWorkspacesFor(access);
      expect(workspaces.contains(ProWorkspace.club), isTrue);
      expect(workspaces.contains(ProWorkspace.coaching), isTrue);
    });

    test(
        'active federation role or appointment maps to ProWorkspace.federation',
        () {
      final withRole = baseAccess(
        federationRoles: [
          FederationRole(
            id: 'fr-1',
            federationId: 'fed-1',
            profileId: 'p-1',
            role: FederationRoleKind.president,
            startsOn: DateTime(2026, 1, 1),
            endsOn: DateTime(2090, 1, 1),
          ),
        ],
      );
      expect(proWorkspacesFor(withRole), contains(ProWorkspace.federation));

      final now = DateTime.now();
      final withAppointment = baseAccess(
        federationAppointments: [
          FederationAppointment(
            id: 'fa-1',
            sportCode: 'football',
            cityCode: '34',
            duty: FederationDuty.resultPublisher,
            startsOn: now.subtract(const Duration(days: 1)),
            endsOn: now.add(const Duration(days: 1)),
          ),
        ],
      );
      expect(
          proWorkspacesFor(withAppointment), contains(ProWorkspace.federation));
    });

    test('active referee maps to referee, inactive referee does not', () {
      final activeRef = baseAccess(
        refereeProfile: fakeReferee(isActive: true),
      );
      expect(proWorkspacesFor(activeRef), contains(ProWorkspace.referee));

      final inactiveRef = baseAccess(
        refereeProfile: fakeReferee(isActive: false),
      );
      expect(
          proWorkspacesFor(inactiveRef), isNot(contains(ProWorkspace.referee)));
    });

    test('non-empty accountant club IDs map to ProWorkspace.accounting', () {
      final access = baseAccess(accountantClubIds: {'club-123'});
      expect(proWorkspacesFor(access), contains(ProWorkspace.accounting));

      final noAccountant = baseAccess(accountantClubIds: {});
      expect(proWorkspacesFor(noAccountant),
          isNot(contains(ProWorkspace.accounting)));
    });

    test('managed or delegated turf ID maps to ProWorkspace.facility', () {
      final managed = baseAccess(managedTurfFieldIds: {'field-1'});
      expect(proWorkspacesFor(managed), contains(ProWorkspace.facility));

      final delegated = baseAccess(delegatedTurfFieldIds: {'field-2'});
      expect(proWorkspacesFor(delegated), contains(ProWorkspace.facility));

      final none = baseAccess();
      expect(proWorkspacesFor(none), isNot(contains(ProWorkspace.facility)));
    });

    test('platform admin maps to ProWorkspace.platform', () {
      final admin = baseAccess(isPlatformAdmin: true);
      expect(proWorkspacesFor(admin), contains(ProWorkspace.platform));

      final notAdmin = baseAccess(isPlatformAdmin: false);
      expect(
          proWorkspacesFor(notAdmin), isNot(contains(ProWorkspace.platform)));
    });

    test(
        'combined multi-role fixture returns all applicable values once in enum order',
        () {
      final multiRole = baseAccess(
        isPlatformAdmin: true,
        clubRole: 'club_admin',
        coachLevel: 3,
        accountantClubIds: {'club-1'},
        managedTurfFieldIds: {'field-1'},
        refereeProfile: fakeReferee(isActive: true),
        federationRoles: [
          FederationRole(
            id: 'fr-1',
            federationId: 'fed-1',
            profileId: 'p-1',
            role: FederationRoleKind.president,
            startsOn: DateTime(2026, 1, 1),
            endsOn: DateTime(2090, 1, 1),
          ),
        ],
      );

      final workspaces = proWorkspacesFor(multiRole);
      expect(
        workspaces,
        equals([
          ProWorkspace.club,
          ProWorkspace.coaching,
          ProWorkspace.federation,
          ProWorkspace.referee,
          ProWorkspace.accounting,
          ProWorkspace.facility,
          ProWorkspace.platform,
        ]),
      );
    });
  });
}

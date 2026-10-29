import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/modules/console_workspace.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  const combined = SwanAccess(
      isPlatformAdmin: true,
      clubRole: 'club_admin',
      coachLevel: 0,
      athleteKind: null);
  const accountant = SwanAccess(
      isPlatformAdmin: false,
      clubRole: null,
      coachLevel: 0,
      athleteKind: null,
      accountantClubIds: {'club'});

  test('workspace selection separates club and platform modules', () {
    expect(consoleWorkspaces(combined),
        [ConsoleWorkspace.club, ConsoleWorkspace.platform]);
    final club = workspaceModules(combined, ConsoleWorkspace.club);
    final platform = workspaceModules(combined, ConsoleWorkspace.platform);
    expect(club.map((m) => m.id), contains('athletes'));
    expect(club.map((m) => m.id), isNot(contains('users')));
    expect(platform.map((m) => m.id), contains('users'));
    expect(platform.map((m) => m.id), isNot(contains('athletes')));
  });

  test('deep links select their workspace and revoked preferences fall back',
      () {
    expect(
        resolveConsoleWorkspace(
            combined, ConsoleWorkspace.club, '/kullanicilar'),
        ConsoleWorkspace.platform);
    expect(
        resolveConsoleWorkspace(
            combined, ConsoleWorkspace.platform, '/sporcular/123'),
        ConsoleWorkspace.club);
    expect(resolveConsoleWorkspace(accountant, ConsoleWorkspace.platform, '/'),
        ConsoleWorkspace.club);
    expect(
        resolveConsoleWorkspace(
            SwanAccess.none, ConsoleWorkspace.platform, '/'),
        isNull);
  });

  test('accountants retain financial access without sporting modules', () {
    expect(consoleWorkspaces(accountant), [ConsoleWorkspace.club]);
    final ids =
        workspaceModules(accountant, ConsoleWorkspace.club).map((m) => m.id);
    expect(ids, contains('ledger'));
    expect(ids, isNot(contains('athletes')));
    expect(ids, isNot(contains('attendance')));
    expect(workspaceModules(accountant, ConsoleWorkspace.platform), isEmpty);
  });
}

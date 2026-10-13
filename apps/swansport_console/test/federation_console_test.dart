import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/modules/module_registry.dart';
import 'package:swansport_console/app/shell/too_narrow_notice.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/features/federation/referee_assignments_screen.dart';
import 'package:swansport_console/features/federation/provincial_leagues_screen.dart';
import 'package:swansport_console/features/federation/disciplinary_board_screen.dart';
import 'package:swansport_data/swansport_data.dart';

SwanAccess _access(FederationRoleKind kind, {bool revoked = false}) => SwanAccess(
  isPlatformAdmin: false, clubRole: null, coachLevel: 0, athleteKind: null,
  federationRoles: [FederationRole(id: 'role', federationId: 'f', profileId: 'p', role: kind,
    startsOn: DateTime(2020), endsOn: DateTime(2090), cityCode: kind == FederationRoleKind.provincialRep ? '34' : null,
    revokedAt: revoked ? DateTime(2021) : null)]);
void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('role-specific modules do not inherit legacy result writer or platform admin privileges', () {
    final president = _access(FederationRoleKind.president);
    for (final route in ['/mhk-atamalar','/il-ligleri','/disiplin-kurulu']) {
      final module = moduleForRoute(route)!;
      expect(module.visibleTo(president), isTrue);
      expect(module.visibleTo(SwanAccess.none), isFalse);
      expect(module.visibleTo(_access(FederationRoleKind.president, revoked: true)), isFalse);
      expect(module.visibleTo(const SwanAccess(isPlatformAdmin: true, clubRole: null, coachLevel: 0, athleteKind: null)), isFalse);
    }
    expect(moduleForRoute('/disiplin-kurulu')!.visibleTo(_access(FederationRoleKind.provincialRep)), isFalse);
    expect(moduleForRoute('/mhk-atamalar')!.visibleTo(_access(FederationRoleKind.refereeCommittee)), isTrue);
    expect(moduleForRoute('/il-ligleri')!.visibleTo(_access(FederationRoleKind.refereeCommittee)), isFalse);
    expect(moduleForRoute('/federasyon-sonuclari')!.visibleTo(president), isFalse);
  });
  testWidgets('direct federation screens preserve the desktop guard', (tester) async {
    tester.view.physicalSize = const Size(800, 700);tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    for (final screen in [const RefereeAssignmentsScreen(),const ProvincialLeaguesScreen(),const DisciplinaryBoardScreen()]) {
      await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: ConsoleTheme.dark(), home: Scaffold(body: screen))));
      expect(find.byType(TooNarrowNotice), findsOneWidget);
    }
  });
  testWidgets('province dialog cannot render a private excuse even from a stale snapshot', (tester) async {
    final match = FederationConsoleMatch(id: 'match', program: 'Lig', sportCode: 'tenis', status: 'scheduled', officials: [
      const ConsoleMatchOfficial(id: 'official', duty: 'head_referee', status: 'declined', declineReason: 'SECRET_EXCUSE')]);
    await tester.pumpWidget(ProviderScope(overrides: [
      consoleAccessProvider.overrideWithValue(_access(FederationRoleKind.provincialRep)),
      authSessionProvider.overrideWith((_) => Stream.value(null)),
      federationConsoleScopesProvider.overrideWith((_) async => [const FederationConsoleScope(
        federationId: 'f', name: 'Federasyon', sportCode: 'tenis', cityCode: '34', role: 'provincial_rep')]),
    ], child: MaterialApp(theme: ConsoleTheme.dark(), home: Scaffold(body: RefereeAssignDialog(match: match, canAssign: false)))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Salt okunur'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Tooltip && w.message == 'SECRET_EXCUSE'), findsNothing);
    expect(find.text('Ata'), findsNothing);
  });
}

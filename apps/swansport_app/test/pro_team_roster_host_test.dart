import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/teams/presentation/screens/team_roster_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('SwanSport roster preserves its full tabs, team id and name',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Kulüp',
              role: 'club_admin',
            ),
          ),
          teamsProvider.overrideWith((ref) async => const []),
          teamRosterProvider('team-1').overrideWith((ref) async => const []),
          clubAthletesProvider.overrideWith((ref) async => const []),
          unlinkedAthletesProvider('club-1')
              .overrideWith((ref) async => const []),
          clubMemberCandidatesProvider('club-1')
              .overrideWith((ref) async => const []),
          officialTeamRostersProvider('team-1')
              .overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: TeamRosterScreen(teamId: 'team-1', teamName: 'U16 Okçuluk'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Takım Kadrosu'), findsOneWidget);
    expect(find.text('U16 Okçuluk'), findsOneWidget);
    expect(find.text('Kadro'), findsOneWidget);
    expect(find.text('Program'), findsOneWidget);
  });
}

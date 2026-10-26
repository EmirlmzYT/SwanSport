import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('invalid target renders a safe state', (tester) async {
    await _pump(
      tester,
      target: const TeamRouteTarget(teamId: '', teamName: ''),
    );
    expect(find.text('Geçerli bir takım seçilmedi.'), findsOneWidget);
  });

  testWidgets('linked and unlinked athletes remain visible and manageable',
      (tester) async {
    final removed = <String>[];
    final navigator = _Navigator();
    await _pump(
      tester,
      navigator: navigator,
      roster: () async => const [
        (id: 'membership-1', athleteId: 'athlete-1', name: 'Ada', jersey: '7'),
        (id: 'membership-2', athleteId: 'athlete-2', name: 'Ece', jersey: null),
      ],
      unlinked: () async => const [
        UnlinkedAthlete(
          athleteId: 'athlete-2',
          firstName: 'Ece',
          lastName: '',
        ),
      ],
      remove: (id) async => removed.add(id),
    );
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Ece'), findsOneWidget);
    expect(find.text('Hesaba bağlı değil'), findsOneWidget);
    await tester.tap(find.text('Ada'));
    expect(navigator.athleteId, 'athlete-1');

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Takımdan çıkar').last);
    await tester.pumpAndSettle();
    expect(removed, ['membership-1']);
  });

  testWidgets('manager can create athlete from approved member and add to team',
      (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      candidates: () async => const [
        ClubMemberCandidate(profileId: 'profile-1', fullName: 'Yeni Üye'),
      ],
      createFromMember: ({required clubId, required profileId}) async {
        calls.add('create:$clubId:$profileId');
        return 'athlete-new';
      },
      add: (teamId, athleteId) async {
        calls.add('add:$teamId:$athleteId');
      },
    );
    await tester.tap(find.text('Yeni Üye'));
    await tester.pumpAndSettle();
    expect(calls, [
      'create:club-1:profile-1',
      'add:team-1:athlete-new',
    ]);
  });

  testWidgets('team change and official projection preserve typed context',
      (tester) async {
    await _pump(
      tester,
      teams: () async => const [
        TeamRow(id: 'team-1', name: 'A Takım'),
        TeamRow(id: 'team-2', name: 'U16'),
      ],
      official: () async => [
        OfficialTeamRoster.fromMap(const {
          'participant_id': 'participant-1',
          'name': 'Lig Esamesi',
          'sport_code': 'football',
          'version': 2,
          'athlete_ids': ['athlete-1'],
        }),
      ],
    );
    expect(find.textContaining('Revizyon 2'), findsOneWidget);
    await tester.tap(find.text('U16'));
    await tester.pumpAndSettle();
    expect(find.text('U16'), findsWidgets);
  });

  testWidgets('read-only membership cannot mutate roster', (tester) async {
    await _pump(
      tester,
      club: const ClubRef(
        id: 'club-1',
        name: 'Kulüp',
        role: 'athlete',
      ),
      roster: () async => const [
        (id: 'membership-1', athleteId: 'athlete-1', name: 'Ada', jersey: null),
      ],
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Kulüp Sporcuları'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  TeamRouteTarget target =
      const TeamRouteTarget(teamId: 'team-1', teamName: 'A Takım'),
  ClubRef club = const ClubRef(
    id: 'club-1',
    name: 'Kulüp',
    role: 'club_admin',
  ),
  Future<List<TeamRow>> Function()? teams,
  Future<List<({String id, String athleteId, String name, String? jersey})>>
          Function()?
      roster,
  Future<List<UnlinkedAthlete>> Function()? unlinked,
  Future<List<ClubMemberCandidate>> Function()? candidates,
  Future<List<OfficialTeamRoster>> Function()? official,
  TeamRosterAddCommand? add,
  TeamRosterRemoveCommand? remove,
  AthleteFromMemberCommand? createFromMember,
  _Navigator? navigator,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeClubProvider.overrideWith((ref) async => club),
        teamsProvider.overrideWith((ref) => (teams ?? () async => const [])()),
        teamRosterProvider(target.teamId)
            .overrideWith((ref) => (roster ?? () async => const [])()),
        clubAthletesProvider.overrideWith((ref) async => const []),
        unlinkedAthletesProvider(club.id)
            .overrideWith((ref) => (unlinked ?? () async => const [])()),
        clubMemberCandidatesProvider(club.id)
            .overrideWith((ref) => (candidates ?? () async => const [])()),
        officialTeamRostersProvider(target.teamId)
            .overrideWith((ref) => (official ?? () async => const [])()),
        swanAccessProvider.overrideWithValue(
          SwanAccess(
            isPlatformAdmin: false,
            clubRole: club.role,
            coachLevel: 0,
            athleteKind: null,
          ),
        ),
        teamRosterAddCommandProvider.overrideWithValue(
          add ?? (teamId, athleteId) async {},
        ),
        teamRosterRemoveCommandProvider.overrideWithValue(
          remove ?? (membershipId) async {},
        ),
        athleteFromMemberCommandProvider.overrideWithValue(
          createFromMember ??
              ({required clubId, required profileId}) async => 'new-athlete',
        ),
      ],
      child: MaterialApp(
        home: ProFeatureHostScope(
          navigator: navigator ?? _Navigator(),
          chrome: const _Chrome(),
          theme: ProFeatureThemeData.light,
          child: SharedTeamRosterScreen(target: target),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _Navigator extends ProFeatureNavigatorBase {
  String? athleteId;
  @override
  bool openAthleteProfile({required String athleteId, String? athleteName}) {
    this.athleteId = athleteId;
    return true;
  }

  @override
  void openAttendance() {}
  @override
  void openAttendanceHistory() {}
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openTeams() {}
  @override
  void openTrainingBuilder() {}
  @override
  void openTrainingList() {}
  @override
  void openTrainingProtocols() {}
  @override
  void openTrainingResult({String? sessionId}) {}
  @override
  void openTrainingSession({String? sessionId}) {}
}

final class _Chrome implements ProFeatureChrome {
  const _Chrome();
  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: body);
  @override
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) async =>
      true;
  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {}
}

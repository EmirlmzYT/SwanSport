import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

const _teams = [
  TeamRow(id: 'youth', name: 'U16 Okçuluk', ageGroup: 'U16', gender: 'Karma'),
  TeamRow(id: 'senior', name: 'A Takım', gender: 'Kadın'),
];

void main() {
  testWidgets('team hub flag gates the shared screen', (tester) async {
    await _pump(
      tester,
      flags: const FeatureFlags.none(),
      teams: () async => throw StateError('teams must not be read'),
    );

    expect(
      find.text('Takım merkezi şu anda kullanıma kapalı.'),
      findsOneWidget,
    );
    expect(find.text('teams must not be read'), findsNothing);
  });

  testWidgets('loading, safe error, and empty states are distinct',
      (tester) async {
    final pending = Completer<List<TeamRow>>();
    await _pump(tester, teams: () => pending.future, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _pump(
      tester,
      teams: () async => throw StateError('PRIVATE BACKEND DETAIL'),
    );
    expect(find.textContaining('Gönderilen bilgiler'), findsOneWidget);
    expect(find.textContaining('PRIVATE BACKEND DETAIL'), findsNothing);

    await _pump(tester, teams: () async => const []);
    expect(
      find.text('Henüz oluşturulmuş bir takım bulunmuyor.'),
      findsOneWidget,
    );
  });

  testWidgets('search filters by team name and age group', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'okçuluk');
    await tester.pump();
    expect(find.text('U16 Okçuluk'), findsOneWidget);
    expect(find.text('A Takım'), findsNothing);

    await tester.enterText(find.byType(TextField), 'u16');
    await tester.pump();
    expect(find.text('U16 Okçuluk'), findsOneWidget);
  });

  testWidgets('category filters use age-group presence without fake data',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Altyapı & Hazırlık'));
    await tester.pump();
    expect(find.text('U16 Okçuluk'), findsOneWidget);
    expect(find.text('A Takım'), findsNothing);

    await tester.tap(find.text('Yarışma Kadroları'));
    await tester.pump();
    expect(find.text('U16 Okçuluk'), findsNothing);
    expect(find.text('A Takım'), findsOneWidget);
  });

  testWidgets('roster and attendance actions use typed host navigation',
      (tester) async {
    final navigator = _Navigator();
    await _pump(tester, navigator: navigator);

    await tester
        .tap(find.widgetWithText(OutlinedButton, 'Kadroyu İncele').first);
    expect(navigator.rosterTarget?.teamId, 'youth');
    expect(navigator.rosterTarget?.teamName, 'U16 Okçuluk');

    await tester.tap(find.widgetWithText(FilledButton, 'Yoklama Al').first);
    expect(navigator.attendanceCalls, 1);
  });

  testWidgets('only a manager can create a team', (tester) async {
    final created = <String>[];
    await _pump(
      tester,
      club: const ClubRef(
        id: 'club-1',
        name: 'Kulüp',
        role: 'coach',
      ),
      createTeam: (clubId, name, {ageGroup, gender}) async {
        created.add('$clubId/$name/$ageGroup/$gender');
      },
    );

    await tester.tap(find.byTooltip('Takım Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni Takım Oluştur'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('team-name-field')),
      'U14 Tenis',
    );
    await tester.enterText(find.byKey(const Key('team-age-field')), 'U14');
    await tester.tap(find.widgetWithText(FilledButton, 'Oluştur'));
    await tester.pumpAndSettle();
    expect(created, ['club-1/U14 Tenis/U14/null']);

    await _pump(
      tester,
      club: const ClubRef(
        id: 'club-1',
        name: 'Kulüp',
        role: 'athlete',
      ),
    );
    expect(find.byTooltip('Takım Ekle'), findsNothing);
  });
}

typedef _CreateTeam = Future<void> Function(
  String clubId,
  String name, {
  String? ageGroup,
  String? gender,
});

Future<void> _pump(
  WidgetTester tester, {
  FeatureFlags flags = const FeatureFlags({FeatureFlags.teamHub}),
  Future<List<TeamRow>> Function()? teams,
  ClubRef club = const ClubRef(
    id: 'club-1',
    name: 'Kulüp',
    role: 'coach',
  ),
  _CreateTeam? createTeam,
  _Navigator? navigator,
  bool settle = true,
}) async {
  final nav = navigator ?? _Navigator();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        featureFlagsProvider.overrideWith((ref) async => flags),
        activeClubProvider.overrideWith((ref) async => club),
        teamsProvider.overrideWith((ref) => (teams ?? () async => _teams)()),
        teamCreateCommandProvider.overrideWithValue(
          createTeam ?? (clubId, name, {ageGroup, gender}) async {},
        ),
      ],
      child: MaterialApp(
        home: ProFeatureHostScope(
          navigator: nav,
          chrome: const _Chrome(),
          theme: ProFeatureThemeData.light,
          child: const SharedTeamDirectoryScreen(),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

final class _Navigator extends ProFeatureNavigatorBase {
  TeamRouteTarget? rosterTarget;
  int attendanceCalls = 0;

  @override
  void openAttendance() => attendanceCalls++;

  @override
  void openAttendanceHistory() {}

  @override
  void openRoster(TeamRouteTarget target) => rosterTarget = target;

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
      Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: body,
        bottomNavigationBar: bottomBar,
      );

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

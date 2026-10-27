import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/swan_bottom_nav.dart';
import 'package:swansport_app/features/teams/presentation/screens/team_roster_directory_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('SwanSport keeps its full team directory experience',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(SwanBottomNav), findsOneWidget);
    expect(find.text('Takımlar & Kadrolar'), findsOneWidget);
    expect(find.text('Yarışma Kadroları'), findsOneWidget);
    expect(find.text('U16 Okçuluk'), findsOneWidget);
  });

  testWidgets('typed roster target preserves legacy route and argument map',
      (tester) async {
    RouteSettings? pushed;
    await tester.pumpWidget(_app(onPush: (settings) => pushed = settings));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Kadroyu İncele'));
    await tester.pumpAndSettle();

    expect(pushed?.name, '/takim-kadro');
    expect(
      pushed?.arguments,
      <String, String>{'id': 'team-1', 'name': 'U16 Okçuluk'},
    );
  });
}

Widget _app({ValueChanged<RouteSettings>? onPush}) => ProviderScope(
      overrides: [
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({FeatureFlags.teamHub}),
        ),
        activeClubProvider.overrideWith(
          (ref) async => const ClubRef(
            id: 'club-1',
            name: 'Kulüp',
            role: 'coach',
          ),
        ),
        teamsProvider.overrideWith(
          (ref) async => const [
            TeamRow(
              id: 'team-1',
              name: 'U16 Okçuluk',
              ageGroup: 'U16',
            ),
          ],
        ),
        teamCreateCommandProvider.overrideWithValue(
          (clubId, name, {ageGroup, gender}) async {},
        ),
      ],
      child: MaterialApp(
        home: const TeamRosterDirectoryScreen(),
        onGenerateRoute: (settings) {
          onPush?.call(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Hedef')),
          );
        },
      ),
    );

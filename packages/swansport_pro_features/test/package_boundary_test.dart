import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('host scope exposes installed adapters and semantic theme',
      (tester) async {
    final navigator = _Navigator();
    final chrome = _Chrome();
    ProFeatureHostScope? observed;

    await tester.pumpWidget(
      MaterialApp(
        home: ProFeatureHostScope(
          navigator: navigator,
          chrome: chrome,
          theme: ProFeatureThemeData.light,
          child: Builder(
            builder: (context) {
              observed = ProFeatureHostScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(observed?.navigator, same(navigator));
    expect(observed?.chrome, same(chrome));
    expect(observed?.theme, same(ProFeatureThemeData.light));
  });

  testWidgets('missing host scope fails with a clear assertion',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      () => ProFeatureHostScope.of(context),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('No ProFeatureHostScope found'),
        ),
      ),
    );
  });

  test('light and dark fixtures define every semantic color', () {
    for (final theme in [
      ProFeatureThemeData.light,
      ProFeatureThemeData.dark,
    ]) {
      final colors = [
        theme.background,
        theme.surface,
        theme.line,
        theme.ink,
        theme.inkMuted,
        theme.accent,
        theme.danger,
        theme.warning,
        theme.success,
      ];
      expect(colors, hasLength(9));
      expect(colors, everyElement(isNot(const Color(0x00000000))));
    }
    expect(
      ProFeatureThemeData.light.background,
      isNot(ProFeatureThemeData.dark.background),
    );
  });

  test('unsupported optional destinations return false', () {
    final navigator = _Navigator();

    expect(navigator.openCalendar(), isFalse);
    expect(
      navigator.openAthleteProfile(athleteId: 'athlete-1'),
      isFalse,
    );
    expect(
      navigator.openConversation(profileId: 'profile-1'),
      isFalse,
    );
    navigator.openFederationMatches();
    navigator.openRefereeAssignments();
    navigator.openLeagueStandings();
    navigator.openDisciplinaryBoard();
    navigator.openFederationBulletins();
    navigator.openRefereeDuties();
    navigator.openRefereeLineup('match-1');
    navigator.openRefereeLiveCockpit('match-1');
    navigator.openRefereeMatchReport('match-1');
  });
}

final class _Navigator extends ProFeatureNavigatorBase {
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
  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      body;

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

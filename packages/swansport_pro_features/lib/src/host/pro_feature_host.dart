import 'package:flutter/material.dart';

import 'pro_feature_theme.dart';

final class TeamRouteTarget {
  const TeamRouteTarget({required this.teamId, required this.teamName});

  final String teamId;
  final String teamName;
}

enum ProFeatureMessageTone { info, success, warning, danger }

/// Typed sections of the desktop web administration console.
/// Shared mobile/Pro screens never pass raw route strings when handing off
/// desktop-only or unsafe-on-mobile platform workflows.
enum PlatformWebConsoleSection {
  missionControl,
  branding,
  plans,
  audit,
  waitlist,
  support,
  diagnostics,
  marketplace,
}

abstract interface class ProFeatureNavigator {
  void openTeams();

  void openRoster(TeamRouteTarget target);

  void openAttendance();

  void openAttendanceHistory();

  void openTrainingList();

  void openTrainingProtocols();

  void openTrainingBuilder();

  void openTrainingSession({String? sessionId});

  void openTrainingResult({String? sessionId});

  void openFederationMatches();

  void openRefereeAssignments();

  void openLeagueStandings();

  void openDisciplinaryBoard();

  void openFederationBulletins();

  void openRefereeDuties();

  void openRefereeLineup(String matchId);

  void openRefereeLiveCockpit(String matchId);

  void openRefereeMatchReport(String matchId);

  void openFinanceOperations();

  void openFinanceLedger();

  void openFinanceCommitments();

  void openBankReconciliation();

  void openClubBudget();

  void openPeriodClosing();

  void openFacilityOperations();

  void openManagedTurfDuties();

  void openFacilitySchedule();

  void openFacilityReservations();

  void openClubInventory();

  void openClubHealthOperations();

  void openClubSportingPlanning();

  void openDevelopmentReport();

  void openPlatformOperations();

  void openPlatformStatus();

  void openPlatformAudit();

  void openPlatformPlans();

  void openLaunchWaitlist();

  bool openPlatformWebConsole([
    PlatformWebConsoleSection section =
        PlatformWebConsoleSection.missionControl,
  ]);

  bool openCalendar();

  bool openAthleteProfile({
    required String athleteId,
    String? athleteName,
  });

  bool openConversation({
    required String profileId,
    String? displayName,
  });
}

/// Convenience base for hosts that do not support optional destinations.
abstract base class ProFeatureNavigatorBase implements ProFeatureNavigator {
  @override
  void openFederationMatches() {}

  @override
  void openRefereeAssignments() {}

  @override
  void openLeagueStandings() {}

  @override
  void openDisciplinaryBoard() {}

  @override
  void openFederationBulletins() {}

  @override
  void openRefereeDuties() {}

  @override
  void openRefereeLineup(String matchId) {}

  @override
  void openRefereeLiveCockpit(String matchId) {}

  @override
  void openRefereeMatchReport(String matchId) {}

  @override
  void openFinanceOperations() {}

  @override
  void openFinanceLedger() {}

  @override
  void openFinanceCommitments() {}

  @override
  void openBankReconciliation() {}

  @override
  void openClubBudget() {}

  @override
  void openPeriodClosing() {}

  @override
  void openFacilityOperations() {}

  @override
  void openManagedTurfDuties() {}

  @override
  void openFacilitySchedule() {}

  @override
  void openFacilityReservations() {}

  @override
  void openClubInventory() {}

  @override
  void openClubHealthOperations() {}

  @override
  void openClubSportingPlanning() {}

  @override
  void openDevelopmentReport() {}

  @override
  void openPlatformOperations() {}

  @override
  void openPlatformStatus() {}

  @override
  void openPlatformAudit() {}

  @override
  void openPlatformPlans() {}

  @override
  void openLaunchWaitlist() {}

  @override
  bool openPlatformWebConsole([
    PlatformWebConsoleSection section =
        PlatformWebConsoleSection.missionControl,
  ]) =>
      false;

  @override
  bool openCalendar() => false;

  @override
  bool openAthleteProfile({required String athleteId, String? athleteName}) =>
      false;

  @override
  bool openConversation({required String profileId, String? displayName}) =>
      false;
}

abstract interface class ProFeatureChrome {
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions,
    Widget? bottomBar,
    bool allowBack,
  });

  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone,
  });

  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel,
  });
}

final class ProFeatureHostScope extends InheritedWidget {
  const ProFeatureHostScope({
    required this.navigator,
    required this.chrome,
    required this.theme,
    required super.child,
    super.key,
  });

  final ProFeatureNavigator navigator;
  final ProFeatureChrome chrome;
  final ProFeatureThemeData theme;

  static ProFeatureHostScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProFeatureHostScope>();

  static ProFeatureHostScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'No ProFeatureHostScope found. Shared professional-operation screens '
      'must be mounted below a host adapter.',
    );
    if (scope == null) {
      throw FlutterError(
        'No ProFeatureHostScope found. Shared professional-operation screens '
        'must be mounted below a host adapter.',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(ProFeatureHostScope oldWidget) =>
      navigator != oldWidget.navigator ||
      chrome != oldWidget.chrome ||
      theme != oldWidget.theme;
}

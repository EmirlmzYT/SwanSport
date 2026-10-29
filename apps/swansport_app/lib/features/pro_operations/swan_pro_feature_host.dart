import 'package:flutter/material.dart';
import 'package:swansport_models/swansport_models.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../app/design/swan_palette.dart';
import '../../app/widgets/swan_bottom_nav.dart';
import '../../app/widgets/swan_module_app_bar.dart';
import '../../app/widgets/swan_scaffold.dart';
import '../athlete_workspace/presentation/routing/athlete_detail_route_args.dart';

final class SwanProFeatureHost extends StatelessWidget {
  const SwanProFeatureHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.swan;
    return ProFeatureHostScope(
      navigator: _SwanFeatureNavigator(context),
      chrome: const _SwanFeatureChrome(),
      theme: ProFeatureThemeData(
        background: palette.bg,
        surface: palette.surface,
        line: palette.line,
        ink: palette.ink,
        inkMuted: palette.inkMuted,
        accent: palette.accent,
        danger: palette.danger,
        warning: palette.warning,
        success: palette.success,
      ),
      child: child,
    );
  }
}

final class _SwanFeatureNavigator extends ProFeatureNavigatorBase {
  _SwanFeatureNavigator(this.context);

  final BuildContext context;

  @override
  void openTeams() => Navigator.pushNamed(context, '/teams');

  @override
  void openRoster(TeamRouteTarget target) => Navigator.pushNamed(
        context,
        '/takim-kadro',
        arguments: {'id': target.teamId, 'name': target.teamName},
      );

  @override
  void openAttendance() => Navigator.pushNamed(context, '/attendance');

  @override
  void openAttendanceHistory() => Navigator.pushNamed(context, '/devam-durumu');

  @override
  void openTrainingList() => Navigator.pushNamed(context, '/antrenmanlarim');

  @override
  void openTrainingProtocols() =>
      Navigator.pushNamed(context, '/antrenman-sablonlari');

  @override
  void openTrainingBuilder() =>
      Navigator.pushNamed(context, '/antrenman-olustur');

  @override
  void openTrainingSession({String? sessionId}) => Navigator.pushNamed(
        context,
        '/antrenman-oturumu',
        arguments: sessionId == null ? null : {'id': sessionId},
      );

  @override
  void openTrainingResult({String? sessionId}) => Navigator.pushNamed(
        context,
        '/antrenman-sonuc',
        arguments: sessionId == null ? null : {'id': sessionId},
      );

  @override
  bool openCalendar() {
    Navigator.pushNamed(context, '/calendar');
    return true;
  }

  @override
  bool openAthleteProfile({
    required String athleteId,
    String? athleteName,
  }) {
    Navigator.pushNamed(
      context,
      '/athlete-detail',
      arguments: AthleteDetailRouteArgs(athleteId: SwanId(athleteId)),
    );
    return true;
  }

  @override
  bool openConversation({required String profileId, String? displayName}) {
    Navigator.pushNamed(
      context,
      '/sohbet',
      arguments: {'id': profileId, 'name': displayName ?? 'Sohbet'},
    );
    return true;
  }

  @override
  void openFederationMatches() =>
      Navigator.pushNamed(context, '/federasyon-merkezi');

  @override
  void openRefereeAssignments() =>
      Navigator.pushNamed(context, '/federasyon-merkezi');

  @override
  void openLeagueStandings() =>
      Navigator.pushNamed(context, '/federasyon-merkezi');

  @override
  void openDisciplinaryBoard() =>
      Navigator.pushNamed(context, '/federasyon-merkezi');

  @override
  void openFederationBulletins() =>
      Navigator.pushNamed(context, '/federasyon-merkezi');

  @override
  void openRefereeDuties() => Navigator.pushNamed(context, '/hakem/gorevler');

  @override
  void openRefereeLineup(String matchId) =>
      Navigator.pushNamed(context, '/hakem/esame/$matchId');

  @override
  void openRefereeLiveCockpit(String matchId) =>
      Navigator.pushNamed(context, '/hakem/canli/$matchId');

  @override
  void openRefereeMatchReport(String matchId) =>
      Navigator.pushNamed(context, '/hakem/rapor/$matchId');

  @override
  void openFinanceOperations() => Navigator.pushNamed(context, '/mali-isler');

  @override
  void openFinanceLedger() =>
      Navigator.pushNamed(context, '/muhasebeci-defter');

  @override
  void openFinanceCommitments() => Navigator.pushNamed(context, '/finans');

  @override
  void openBankReconciliation() => Navigator.pushNamed(context, '/finans');

  @override
  void openClubBudget() => Navigator.pushNamed(context, '/finans');

  @override
  void openPeriodClosing() => Navigator.pushNamed(context, '/ters-islem');

  @override
  void openFacilityOperations() =>
      Navigator.pushNamed(context, '/saha-islemlerim');

  @override
  void openManagedTurfDuties() =>
      Navigator.pushNamed(context, '/saha-islemlerim');

  @override
  void openFacilitySchedule() =>
      Navigator.pushNamed(context, '/saha-islemlerim');

  @override
  void openFacilityReservations() =>
      Navigator.pushNamed(context, '/saha-islemlerim');

  @override
  void openClubInventory() =>
      Navigator.pushNamed(context, '/kulup/malzeme-zimmet');

  @override
  void openClubHealthOperations() =>
      Navigator.pushNamed(context, '/kulup/saglik-takibi');

  @override
  void openClubSportingPlanning() =>
      Navigator.pushNamed(context, '/kulup/kadro-planlama');

  @override
  void openDevelopmentReport() =>
      Navigator.pushNamed(context, '/gelisim-raporu');
}

final class _SwanFeatureChrome implements ProFeatureChrome {
  const _SwanFeatureChrome();

  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      SwanScaffold(
        appBar: swanModuleAppBar(context, title: title, actions: actions),
        extendBody: true,
        backgroundColor: context.swan.bg,
        body: body,
        bottomNavigationBar: bottomBar ?? const SwanBottomNav(),
      );

  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {
    final palette = context.swan;
    final color = switch (tone) {
      ProFeatureMessageTone.info => palette.ink,
      ProFeatureMessageTone.success => palette.success,
      ProFeatureMessageTone.warning => palette.warning,
      ProFeatureMessageTone.danger => palette.danger,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

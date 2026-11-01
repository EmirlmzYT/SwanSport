import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('renders filters and accessible real-data summaries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.developmentReport}),
          ),
          reportAthletesProvider.overrideWith(
            (ref, request) async => const ReportAthletePage(
              [
                ReportAthlete(
                  id: 'athlete-1',
                  name: 'Ada Sporcu',
                  teamId: 'team-1',
                  teamName: 'U16',
                  sportCode: 'basketbol',
                ),
              ],
              false,
            ),
          ),
          developmentReportProvider.overrideWith(
            (ref, request) async => _report,
          ),
        ],
        child: MaterialApp(
          home: ProFeatureHostScope(
            navigator: _Navigator(),
            chrome: const _Chrome(),
            theme: ProFeatureThemeData.light,
            child: const ProDevelopmentAnalyticsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('development-report-team')), findsOneWidget);
    expect(find.byKey(const Key('development-report-sport')), findsOneWidget);
    await tester.tap(find.byKey(const Key('development-report-athlete')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Ada Sporcu').last);
    await tester.pumpAndSettle();
    expect(find.text('Devam eğilimi'), findsOneWidget);
    expect(find.text('Antrenman sonuçları'), findsOneWidget);
    expect(find.textContaining('Toplam 42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _report = DevelopmentReport(
  athlete: const ReportAthlete(id: 'athlete-1', name: 'Ada Sporcu'),
  from: DateTime(2026, 8, 1),
  to: DateTime(2026, 10, 30),
  generatedAt: DateTime(2026, 10, 30),
  fingerprint: 'fingerprint',
  attendance: const ReportAttendance(
    present: 8,
    late: 1,
    absent: 1,
    excused: 0,
    unlinked: 0,
    rate: 90,
  ),
  metrics: const [],
  goals: const [],
  trainingResults: [
    ReportTrainingResult(
      sessionId: 'session-1',
      protocolName: 'Teknik seri',
      sportCode: 'basketbol',
      startedAt: DateTime(2026, 10, 20),
      setsRecorded: 3,
      totalScore: 42,
      averageSet: 14,
      bestSet: 16,
    ),
  ],
);

final class _Navigator extends ProFeatureNavigatorBase {
  @override
  void openTeams() {}
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openAttendance() {}
  @override
  void openAttendanceHistory() {}
  @override
  void openTrainingList() {}
  @override
  void openTrainingProtocols() {}
  @override
  void openTrainingBuilder() {}
  @override
  void openTrainingSession({String? sessionId}) {}
  @override
  void openTrainingResult({String? sessionId}) {}
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
      Scaffold(body: body);
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

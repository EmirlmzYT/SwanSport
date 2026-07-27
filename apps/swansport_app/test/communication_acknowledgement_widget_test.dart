import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/acknowledge_communication_command.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
import 'package:swansport_app/features/announcements/presentation/screens/announcements_screen.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  const emergencyAction = Key('acknowledge-communication_emergency');

  CommunicationCenterController controller({
    CommunicationRole role = CommunicationRole.athlete,
    SwanId actingRecipientId = const SwanId('athlete_eligible'),
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
    FixtureCommunicationCenterRepository? repository,
  }) =>
      CommunicationCenterController(
        repository: repository ??
            FixtureCommunicationCenterRepository(
              const FixtureCommunicationCenterDataSource(),
            ),
        role: role,
        actingRecipientId: actingRecipientId,
        scenario: scenario,
        clock: () => DateTime(2026, 7, 23, 16),
      );

  Future<void> pump(
    WidgetTester tester,
    CommunicationCenterController subject,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communicationCenterControllerProvider.overrideWith((ref) => subject),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets('required pending indicator and eligible action are visible',
      (tester) async {
    await pump(tester, controller());
    await reveal(tester, find.byKey(emergencyAction));
    expect(find.byKey(emergencyAction), findsOneWidget);
    expect(
      find.byKey(
        const Key(
          'acknowledgement-status-communication_emergency',
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const Key(
                'acknowledgement-status-communication_emergency',
              ),
            ),
          )
          .data,
      'Onay bekleniyor',
    );
  });

  testWidgets(
      'acknowledgement success updates aggregate and acknowledged state',
      (tester) async {
    final subject = controller();
    await pump(tester, subject);
    await reveal(tester, find.byKey(emergencyAction));
    await tester.tap(find.byKey(emergencyAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('acknowledgement-success')), findsOneWidget);
    expect(find.text('Onaylandı'), findsOneWidget);
    expect(
      subject.state.acknowledgementResult!.acknowledgedCount,
      43,
    );
  });

  testWidgets('unauthorized role cannot act and read remains distinct',
      (tester) async {
    await pump(tester, controller(role: CommunicationRole.headCoach));
    await reveal(
      tester,
      find.byKey(
        const Key(
          'acknowledgement-status-communication_emergency',
        ),
      ),
    );
    expect(find.byKey(emergencyAction), findsNothing);
    expect(find.textContaining('Okundu'), findsWidgets);
    expect(find.textContaining('Onay'), findsWidgets);
  });

  testWidgets('permission, offline and recoverable feedback are safe',
      (tester) async {
    final cases = [
      controller(actingRecipientId: const SwanId('athlete_other')),
      controller(scenario: CommunicationFixtureScenario.offline),
      controller(
        scenario: CommunicationFixtureScenario.acknowledgementFailure,
      ),
    ];
    for (final subject in cases) {
      await pump(tester, subject);
      await reveal(tester, find.byKey(emergencyAction));
      await tester.tap(find.byKey(emergencyAction));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('acknowledgement-error')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('submitting disables duplicate interaction', (tester) async {
    final repository = _DelayedWidgetAcknowledgementRepository();
    await pump(tester, controller(repository: repository));
    await reveal(tester, find.byKey(emergencyAction));
    await tester.tap(find.byKey(emergencyAction));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(emergencyAction)).onPressed,
      isNull,
    );
    expect(find.text('Onaylanıyor…'), findsOneWidget);
    expect(repository.calls, 1);
  });
}

class _DelayedWidgetAcknowledgementRepository
    extends FixtureCommunicationCenterRepository {
  _DelayedWidgetAcknowledgementRepository()
      : super(const FixtureCommunicationCenterDataSource());

  int calls = 0;
  final completer = Completer<AppResult<CommunicationAcknowledgementResult>>();

  @override
  Future<AppResult<CommunicationAcknowledgementResult>> acknowledge(
    AcknowledgeCommunicationCommand command, {
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) {
    calls++;
    return completer.future;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
import 'package:swansport_app/features/announcements/presentation/routing/communication_detail_route_args.dart';
import 'package:swansport_app/features/announcements/presentation/screens/communication_detail_screen.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    String id = 'communication_emergency',
    CommunicationRole role = CommunicationRole.headCoach,
    SwanId recipient = const SwanId('athlete_eligible'),
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
    FixtureCommunicationCenterRepository? repository,
    Size size = const Size(1024, 900),
    ThemeMode themeMode = ThemeMode.light,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communicationCenterRepositoryProvider.overrideWithValue(
            repository ??
                FixtureCommunicationCenterRepository(
                  const FixtureCommunicationCenterDataSource(),
                ),
          ),
        ],
        child: MaterialApp(
          theme: SwanTheme.light(),
          darkTheme: SwanTheme.dark(),
          themeMode: themeMode,
          home: CommunicationDetailScreen(
            args: CommunicationDetailRouteArgs(
              communicationId: SwanId(id),
              role: role,
              actingRecipientId: recipient,
            ),
            scenario: scenario,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('renders loading and loaded emergency communication details',
      (tester) async {
    final delayed = _DelayedDetailRepository();
    await pumpDetail(tester, repository: delayed, settle: false);
    expect(
      find.byKey(const Key('communication-detail-loading')),
      findsOneWidget,
    );
    delayed.completer.complete(
      AppSuccess(
        const FixtureCommunicationCenterDataSource()
            .items
            .singleWhere((item) => item.id.value == 'communication_emergency'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acil Durum Uyarısı'), findsOneWidget);
    expect(
      find.byKey(const Key('communication-detail-sender')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('communication-detail-body')), findsOneWidget);
    expect(find.text('Acil İleti'), findsOneWidget);
    expect(find.text('Acil'), findsOneWidget);
  });

  testWidgets('renders pinned, attachment, scheduled and unavailable states',
      (tester) async {
    await pumpDetail(tester, id: 'communication_facility');
    expect(find.text('Sabitlendi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await pumpDetail(tester, id: 'communication_schedule');
    expect(find.text('Planlandı'), findsOneWidget);
    expect(find.text('Veli Muvafakatnamesi.pdf'), findsOneWidget);
    expect(find.textContaining('Planlanan:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await pumpDetail(tester, id: 'communication_cancelled');
    expect(
      find.byKey(const Key('communication-detail-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('delivery and acknowledgement privacy follow role permissions',
      (tester) async {
    await pumpDetail(tester);
    expect(
      find.byKey(const Key('communication-detail-read-progress')),
      findsOneWidget,
    );
    expect(find.textContaining('Onay'), findsWidgets);
    await tester.pumpWidget(const SizedBox());

    for (final role in [
      CommunicationRole.athlete,
      CommunicationRole.guardian,
    ]) {
      await pumpDetail(tester, role: role);
      expect(
        find.byKey(const Key('communication-detail-read-progress')),
        findsNothing,
      );
      expect(find.text('Onay bekleniyor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('eligible recipient acknowledges with distinct read state',
      (tester) async {
    await pumpDetail(tester, role: CommunicationRole.athlete);
    expect(
      find.byKey(const Key('communication-detail-acknowledge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('communication-detail-read-progress')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('communication-detail-acknowledge')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('communication-detail-acknowledgement-success')),
      findsOneWidget,
    );
    expect(find.text('Onaylandı'), findsWidgets);
  });

  testWidgets('renders not-found, permission, offline and recoverable failure',
      (tester) async {
    await pumpDetail(tester, id: 'missing');
    expect(
      find.byKey(const Key('communication-detail-not-found')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());

    await pumpDetail(
      tester,
      id: 'communication_facility',
      role: CommunicationRole.guardian,
    );
    expect(
      find.byKey(const Key('communication-detail-permission-denied')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());

    await pumpDetail(
      tester,
      role: CommunicationRole.athlete,
      scenario: CommunicationFixtureScenario.offline,
    );
    expect(
      find.byKey(const Key('communication-detail-offline')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());

    await pumpDetail(
      tester,
      scenario: CommunicationFixtureScenario.error,
    );
    expect(
      find.byKey(const Key('communication-detail-failure')),
      findsOneWidget,
    );
  });

  testWidgets('acknowledgement failure renders safely', (tester) async {
    await pumpDetail(
      tester,
      role: CommunicationRole.athlete,
      scenario: CommunicationFixtureScenario.acknowledgementFailure,
    );
    await tester.tap(
      find.byKey(const Key('communication-detail-acknowledge')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('communication-detail-acknowledgement-error')),
      findsOneWidget,
    );
  });

  testWidgets('is overflow-safe across required widths and dark modes',
      (tester) async {
    for (final width in [375.0, 600.0, 768.0, 1024.0, 1440.0]) {
      await pumpDetail(tester, size: Size(width, 900));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    for (final width in [375.0, 1024.0]) {
      await pumpDetail(
        tester,
        size: Size(width, 900),
        themeMode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}

class _DelayedDetailRepository extends FixtureCommunicationCenterRepository {
  _DelayedDetailRepository()
      : super(const FixtureCommunicationCenterDataSource());

  final completer = Completer<AppResult<CommunicationItem>>();

  @override
  Future<AppResult<CommunicationItem>> getDetail(
    SwanId id, {
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) =>
      completer.future;
}

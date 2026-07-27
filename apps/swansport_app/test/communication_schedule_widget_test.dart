import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/application/communication_composer_draft.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/models/schedule_communication_command.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
import 'package:swansport_app/features/announcements/presentation/screens/announcements_screen.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  final now = DateTime(2026, 7, 23, 10);
  final future = DateTime(2026, 7, 24, 12);
  const audience = CommunicationAudience(
    segments: {AudienceSegment.team},
    recipientIds: {SwanId('u16')},
  );

  CommunicationCenterController controller({
    CommunicationRole role = CommunicationRole.headCoach,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
    FixtureCommunicationCenterRepository? repository,
  }) =>
      CommunicationCenterController(
        repository: repository ??
            FixtureCommunicationCenterRepository(
              const FixtureCommunicationCenterDataSource(),
            ),
        role: role,
        scenario: scenario,
        clock: () => now,
      );

  Future<void> prepare(
    CommunicationCenterController subject, {
    DateTime? at,
    bool includeAudience = true,
  }) async {
    subject.updateComposer(
      CommunicationComposerDraft(
        title: 'Widget Planı',
        body: 'Taslak içeriği',
        audience: includeAudience
            ? audience
            : const CommunicationAudience(segments: {}, recipientIds: {}),
        schedule: at == null ? null : CommunicationSchedule(publishAt: at),
      ),
    );
    if (includeAudience) await subject.resolveDraftAudience();
  }

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

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_comment_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> revealSubmit(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('composer-scroll')),
      const Offset(0, -800),
    );
    await tester.pump();
  }

  testWidgets('authorized composer exposes usable date and time controls',
      (tester) async {
    final subject = controller();
    await prepare(subject);
    await pump(tester, subject);
    await open(tester);
    expect(find.byKey(const Key('schedule-date-time')), findsOneWidget);
    expect(find.byKey(const Key('schedule-submit')), findsOneWidget);
    subject.updateComposer(
      subject.state.composerDraft.copyWith(
        schedule: CommunicationSchedule(publishAt: future),
      ),
    );
    await tester.pump();
    expect(subject.state.composerDraft.schedule, isNotNull);
    expect(find.textContaining('24.07.2026'), findsOneWidget);
  });

  testWidgets('unauthorized role cannot schedule', (tester) async {
    await pump(tester, controller(role: CommunicationRole.athlete));
    expect(find.byIcon(Icons.add_comment_rounded), findsNothing);
    expect(find.byKey(const Key('schedule-submit')), findsNothing);
  });

  testWidgets('past and empty audience validation are visible', (tester) async {
    final past = controller();
    await prepare(
      past,
      at: now.subtract(const Duration(minutes: 1)),
    );
    await pump(tester, past);
    await open(tester);
    await revealSubmit(tester);
    await tester.tap(find.byKey(const Key('schedule-submit')));
    await tester.pump();
    expect(find.textContaining('gelecekte'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    final empty = controller();
    await prepare(empty, at: future, includeAudience: false);
    await pump(tester, empty);
    await open(tester);
    await revealSubmit(tester);
    await tester.tap(find.byKey(const Key('schedule-submit')));
    await tester.pump();
    expect(find.byKey(const Key('schedule-error')), findsOneWidget);
  });

  testWidgets('success is rendered and scheduled communication is observable',
      (tester) async {
    final subject = controller();
    await prepare(subject, at: future);
    await pump(tester, subject);
    await open(tester);
    await revealSubmit(tester);
    await tester.tap(find.byKey(const Key('schedule-submit')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('schedule-success')), findsOneWidget);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Widget Planı'), findsWidgets);
  });

  testWidgets('failure and offline feedback preserve draft values',
      (tester) async {
    for (final scenario in [
      CommunicationFixtureScenario.scheduleFailure,
      CommunicationFixtureScenario.offline,
    ]) {
      final subject = controller(scenario: scenario);
      await prepare(subject, at: future);
      await pump(tester, subject);
      await open(tester);
      await revealSubmit(tester);
      await tester.tap(find.byKey(const Key('schedule-submit')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('schedule-error')), findsOneWidget);
      expect(subject.state.composerDraft.title, 'Widget Planı');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('composer-title')))
            .initialValue,
        'Widget Planı',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('progress disables duplicate schedule submission',
      (tester) async {
    final repository = _DelayedWidgetScheduleRepository();
    final subject = controller(repository: repository);
    await prepare(subject, at: future);
    await pump(tester, subject);
    await open(tester);
    final submit = find.byKey(const Key('schedule-submit'));
    await revealSubmit(tester);
    await tester.tap(submit);
    await tester.pump();
    expect(find.byKey(const Key('schedule-progress')), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(repository.calls, 1);
  });
}

class _DelayedWidgetScheduleRepository
    extends FixtureCommunicationCenterRepository {
  _DelayedWidgetScheduleRepository()
      : super(const FixtureCommunicationCenterDataSource());

  int calls = 0;
  final completer = Completer<AppResult<CommunicationItem>>();

  @override
  Future<AppResult<CommunicationItem>> schedule(
    ScheduleCommunicationCommand command, {
    required CommunicationRole role,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
  }) {
    calls++;
    return completer.future;
  }
}

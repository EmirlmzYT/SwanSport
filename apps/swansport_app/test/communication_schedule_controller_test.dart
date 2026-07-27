import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/application/communication_center_state.dart';
import 'package:swansport_app/features/announcements/application/communication_composer_draft.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/models/schedule_communication_command.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
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
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
    CommunicationRole role = CommunicationRole.headCoach,
    FixtureCommunicationCenterRepository? repository,
  }) =>
      CommunicationCenterController(
        repository: repository ??
            FixtureCommunicationCenterRepository(
              const FixtureCommunicationCenterDataSource(),
            ),
        scenario: scenario,
        role: role,
        clock: () => now,
      );

  CommunicationComposerDraft draft({
    DateTime? at,
    String title = 'Yeni İleti',
  }) =>
      CommunicationComposerDraft(
        title: title,
        body: 'Planlanacak içerik',
        audience: audience,
        schedule: at == null ? null : CommunicationSchedule(publishAt: at),
      );

  Future<void> prepare(
    CommunicationCenterController subject, {
    DateTime? at,
    String title = 'Yeni İleti',
  }) async {
    await Future<void>.delayed(Duration.zero);
    subject.updateComposer(draft(at: at, title: title));
    await subject.resolveDraftAudience();
  }

  test('starts idle and emits validating, scheduling and success', () async {
    final subject = controller();
    await prepare(subject, at: future);
    expect(subject.state.schedulingStatus, CommunicationSchedulingStatus.idle);
    final transitions = <CommunicationSchedulingStatus>[];
    subject.addListener((value) => transitions.add(value.schedulingStatus));
    await subject.scheduleCurrentDraft();
    expect(transitions, contains(CommunicationSchedulingStatus.validating));
    expect(transitions, contains(CommunicationSchedulingStatus.scheduling));
    expect(
      subject.state.schedulingStatus,
      CommunicationSchedulingStatus.success,
    );
    expect(subject.state.composerDraft.title, isEmpty);
    expect(subject.state.scheduledItem!.status, CommunicationStatus.scheduled);
    expect(
      subject.state.workspace!.items.any(
        (item) => item.id.value == subject.state.scheduledItem!.id.value,
      ),
      isTrue,
    );
  });

  test('validates missing, past, invalid and unresolved drafts', () async {
    final missing = controller();
    await prepare(missing);
    await missing.scheduleCurrentDraft();
    expect(
      missing.state.schedulingStatus,
      CommunicationSchedulingStatus.validationFailure,
    );

    final past = controller();
    await prepare(past, at: now.subtract(const Duration(minutes: 1)));
    await past.scheduleCurrentDraft();
    expect(
      past.state.schedulingStatus,
      CommunicationSchedulingStatus.validationFailure,
    );

    final invalid = controller();
    await prepare(invalid, at: future, title: '');
    await invalid.scheduleCurrentDraft();
    expect(
      invalid.state.schedulingStatus,
      CommunicationSchedulingStatus.validationFailure,
    );

    final unresolved = controller();
    await Future<void>.delayed(Duration.zero);
    unresolved.updateComposer(draft(at: future));
    await unresolved.scheduleCurrentDraft();
    expect(unresolved.state.schedulingError, contains('çözümlenmelidir'));
  });

  test('maps permission, offline and repository failures preserving draft',
      () async {
    final denied = controller(role: CommunicationRole.athlete);
    await Future<void>.delayed(Duration.zero);
    denied.updateComposer(draft(at: future));
    await denied.scheduleCurrentDraft();
    expect(
      denied.state.schedulingStatus,
      CommunicationSchedulingStatus.permissionFailure,
    );
    expect(denied.state.composerDraft.title, 'Yeni İleti');

    final offline = controller(scenario: CommunicationFixtureScenario.offline);
    await prepare(offline, at: future);
    await offline.scheduleCurrentDraft();
    expect(
      offline.state.schedulingStatus,
      CommunicationSchedulingStatus.offlineFailure,
    );
    expect(offline.state.composerDraft.title, 'Yeni İleti');

    final failed =
        controller(scenario: CommunicationFixtureScenario.scheduleFailure);
    await prepare(failed, at: future);
    await failed.scheduleCurrentDraft();
    expect(
      failed.state.schedulingStatus,
      CommunicationSchedulingStatus.repositoryFailure,
    );
    expect(failed.state.composerDraft.title, 'Yeni İleti');
  });

  test('duplicate action is blocked and stale result cannot overwrite draft',
      () async {
    final repository = _DelayedScheduleRepository();
    final subject = controller(repository: repository);
    await prepare(subject, at: future);
    final first = subject.scheduleCurrentDraft();
    final duplicate = subject.scheduleCurrentDraft();
    expect(repository.calls, 1);
    expect(
      subject.state.schedulingStatus,
      CommunicationSchedulingStatus.scheduling,
    );
    await duplicate;
    subject.updateComposer(draft(at: future, title: 'Daha Yeni Taslak'));
    repository.completer.complete(
      const AppError(
        AppFailure(
          code: 'schedule_repository_failure',
          message: 'Eski yanıt',
        ),
      ),
    );
    await first;
    expect(subject.state.composerDraft.title, 'Daha Yeni Taslak');
    expect(subject.state.schedulingStatus, CommunicationSchedulingStatus.idle);
  });
}

class _DelayedScheduleRepository extends FixtureCommunicationCenterRepository {
  _DelayedScheduleRepository()
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

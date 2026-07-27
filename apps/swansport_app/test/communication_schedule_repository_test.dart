import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_composer_draft.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/audience_resolution.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/domain/models/schedule_communication_command.dart';
import 'package:swansport_app/features/announcements/domain/repositories/communication_center_repository.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  final now = DateTime(2026, 7, 23, 10);
  final future = DateTime(2026, 7, 24, 12, 30);
  const audience = CommunicationAudience(
    segments: {AudienceSegment.team},
    recipientIds: {SwanId('u16')},
  );
  const resolved = ResolvedAudience(
    recipientIds: [SwanId('athlete_ali'), SwanId('staff_coach')],
    preview: AudienceRecipientPreview(
      total: 2,
      categoryCounts: {
        AudienceRecipientCategory.athlete: 1,
        AudienceRecipientCategory.staff: 1,
      },
      audienceLabels: ['team: u16'],
    ),
  );

  CommunicationComposerDraft draft({
    DateTime? at,
    String title = 'Haftalık Program',
    CommunicationAudience selectedAudience = audience,
  }) =>
      CommunicationComposerDraft(
        title: title,
        body: 'Program ayrıntıları',
        type: CommunicationType.bulletin,
        priority: CommunicationPriority.high,
        audience: selectedAudience,
        attachments: const [
          CommunicationAttachment(
            id: SwanId('schedule_attachment'),
            type: AttachmentType.document,
            name: 'program.pdf',
          ),
        ],
        requiresAcknowledgement: true,
        schedule: at == null ? null : CommunicationSchedule(publishAt: at),
      );

  ScheduleCommunicationCommand command(
    CommunicationComposerDraft value, {
    String key = 'schedule-key',
    ResolvedAudience audienceResult = resolved,
  }) =>
      ScheduleCommunicationCommand(
        draft: value,
        resolvedAudience: audienceResult,
        type: value.type,
        senderId: const SwanId('sender_headCoach'),
        now: now,
        idempotencyKey: key,
      );

  test('valid schedule mutates fixture and reload observes metadata', () async {
    final repository = FixtureCommunicationCenterRepository(
      const FixtureCommunicationCenterDataSource(),
    );
    final result = await repository.schedule(
      command(draft(at: future)),
      role: CommunicationRole.headCoach,
    );
    final item = (result as AppSuccess<CommunicationItem>).value;
    expect(item.id.value, 'scheduled_0001');
    expect(item.status, CommunicationStatus.scheduled);
    expect(item.schedule!.publishAt, future);
    expect(item.type, CommunicationType.bulletin);
    expect(item.priority, CommunicationPriority.high);
    expect(item.sender, 'sender_headCoach');
    expect(item.attachments.single.name, 'program.pdf');
    expect(item.acknowledgement.status, AcknowledgementStatus.pending);
    expect(item.delivery.sent, 0);
    expect(item.delivery.read, 0);

    final workspace = await repository.loadWorkspace(
      filters: const CommunicationFilterState(),
      role: CommunicationRole.headCoach,
    );
    expect(
      (workspace as AppSuccess<CommunicationWorkspace>)
          .value
          .items
          .any((entry) => entry.id.value == 'scheduled_0001'),
      isTrue,
    );
  });

  test('duplicate idempotency key returns one stable record', () async {
    final repository = FixtureCommunicationCenterRepository(
      const FixtureCommunicationCenterDataSource(),
    );
    final first = await repository.schedule(
      command(draft(at: future)),
      role: CommunicationRole.headCoach,
    );
    final second = await repository.schedule(
      command(draft(at: future)),
      role: CommunicationRole.headCoach,
    );
    expect(
      (first as AppSuccess<CommunicationItem>).value.id.value,
      (second as AppSuccess<CommunicationItem>).value.id.value,
    );
    final workspace = await repository.loadWorkspace(
      filters: const CommunicationFilterState(),
      role: CommunicationRole.headCoach,
    );
    expect(
      (workspace as AppSuccess<CommunicationWorkspace>)
          .value
          .items
          .where((item) => item.id.value.startsWith('scheduled_'))
          .length,
      1,
    );
  });

  test('repository rejects invalid, past, empty and unresolved drafts',
      () async {
    final repository = FixtureCommunicationCenterRepository(
      const FixtureCommunicationCenterDataSource(),
    );
    final cases = [
      command(draft(at: future, title: '')),
      command(draft(at: now.subtract(const Duration(minutes: 1)))),
      command(
        draft(
          at: future,
          selectedAudience: const CommunicationAudience(
            segments: {},
            recipientIds: {},
          ),
        ),
      ),
      command(
        draft(at: future),
        audienceResult: const ResolvedAudience(
          recipientIds: [],
          preview: AudienceRecipientPreview(
            total: 0,
            categoryCounts: {},
            audienceLabels: [],
          ),
        ),
      ),
    ];
    for (final value in cases) {
      expect(
        await repository.schedule(
          value,
          role: CommunicationRole.headCoach,
        ),
        isA<AppError<CommunicationItem>>(),
      );
    }
  });

  test('repository enforces permission, offline and recoverable failure',
      () async {
    final repository = FixtureCommunicationCenterRepository(
      const FixtureCommunicationCenterDataSource(),
    );
    final value = command(draft(at: future));
    final denied = await repository.schedule(
      value,
      role: CommunicationRole.athlete,
    );
    expect(
      (denied as AppError<CommunicationItem>).failure.code,
      'schedule_permission_denied',
    );
    final offline = await repository.schedule(
      value,
      role: CommunicationRole.headCoach,
      scenario: CommunicationFixtureScenario.offline,
    );
    expect(
      (offline as AppError<CommunicationItem>).failure.code,
      'schedule_offline',
    );
    final failed = await repository.schedule(
      value,
      role: CommunicationRole.headCoach,
      scenario: CommunicationFixtureScenario.scheduleFailure,
    );
    expect(
      (failed as AppError<CommunicationItem>).failure.code,
      'schedule_repository_failure',
    );
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/application/communication_center_controller.dart';
import 'package:swansport_app/features/announcements/application/communication_center_state.dart';
import 'package:swansport_app/features/announcements/data/fixtures/communication_center_fixture_data_source.dart';
import 'package:swansport_app/features/announcements/data/fixtures/fixture_audience_resolver.dart';
import 'package:swansport_app/features/announcements/data/repositories/fixture_communication_center_repository.dart';
import 'package:swansport_app/features/announcements/domain/models/audience_resolution.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  CommunicationCenterController controller({
    AudienceResolver resolver = const FixtureAudienceResolver(),
    CommunicationRole role = CommunicationRole.headCoach,
  }) =>
      CommunicationCenterController(
        repository: FixtureCommunicationCenterRepository(
          const FixtureCommunicationCenterDataSource(),
        ),
        audienceResolver: resolver,
        role: role,
      );

  const team = CommunicationAudience(
    segments: {AudienceSegment.team},
    recipientIds: {SwanId('u16')},
  );

  test('starts idle, resolves, invalidates on change, and clears', () async {
    final subject = controller();
    await Future<void>.delayed(Duration.zero);
    expect(
      subject.state.audienceResolutionStatus,
      AudienceResolutionStatus.idle,
    );
    subject
        .updateComposer(subject.state.composerDraft.copyWith(audience: team));
    await subject.resolveDraftAudience();
    expect(
      subject.state.audienceResolutionStatus,
      AudienceResolutionStatus.resolved,
    );
    expect(subject.state.resolvedAudience!.totalUniqueRecipients, 3);
    subject.updateComposer(
      subject.state.composerDraft.copyWith(
        audience: const CommunicationAudience(
          segments: {AudienceSegment.club},
          recipientIds: {SwanId('club')},
        ),
      ),
    );
    expect(
      subject.state.audienceResolutionStatus,
      AudienceResolutionStatus.idle,
    );
    expect(subject.state.resolvedAudience, isNull);
    subject.clearAudiencePreview();
    expect(subject.state.resolvedAudience, isNull);
  });

  test('maps validation, permission and repository failures', () async {
    final empty = controller();
    await Future<void>.delayed(Duration.zero);
    await empty.resolveDraftAudience();
    expect(
      empty.state.audienceResolutionStatus,
      AudienceResolutionStatus.validationFailure,
    );

    final denied = controller(role: CommunicationRole.athlete);
    await Future<void>.delayed(Duration.zero);
    denied.updateComposer(denied.state.composerDraft.copyWith(audience: team));
    await denied.resolveDraftAudience();
    expect(
      denied.state.audienceResolutionStatus,
      AudienceResolutionStatus.permissionFailure,
    );

    final failed = controller(resolver: const _FailingResolver());
    await Future<void>.delayed(Duration.zero);
    failed.updateComposer(failed.state.composerDraft.copyWith(audience: team));
    await failed.resolveDraftAudience();
    expect(
      failed.state.audienceResolutionStatus,
      AudienceResolutionStatus.repositoryFailure,
    );
  });

  test('exposes resolving and ignores stale asynchronous responses', () async {
    final resolver = _DelayedResolver();
    final subject = controller(resolver: resolver);
    await Future<void>.delayed(Duration.zero);
    subject
        .updateComposer(subject.state.composerDraft.copyWith(audience: team));
    final pending = subject.resolveDraftAudience();
    expect(
      subject.state.audienceResolutionStatus,
      AudienceResolutionStatus.resolving,
    );
    subject.updateComposer(
      subject.state.composerDraft.copyWith(
        audience: const CommunicationAudience(
          segments: {AudienceSegment.club},
          recipientIds: {SwanId('club')},
        ),
      ),
    );
    resolver.completer.complete(
      const AppSuccess(
        ResolvedAudience(
          recipientIds: [SwanId('stale')],
          preview: AudienceRecipientPreview(
            total: 1,
            categoryCounts: {AudienceRecipientCategory.staff: 1},
            audienceLabels: ['stale'],
          ),
        ),
      ),
    );
    await pending;
    expect(subject.state.resolvedAudience, isNull);
    expect(
      subject.state.audienceResolutionStatus,
      AudienceResolutionStatus.idle,
    );
  });
}

class _FailingResolver implements AudienceResolver {
  const _FailingResolver();

  @override
  Future<AppResult<ResolvedAudience>> resolve(
    CommunicationAudience audience, {
    required CommunicationRole role,
  }) async =>
      const AppError(
        AppFailure(code: 'repository_failure', message: 'Resolver failed'),
      );
}

class _DelayedResolver implements AudienceResolver {
  final completer = Completer<AppResult<ResolvedAudience>>();

  @override
  Future<AppResult<ResolvedAudience>> resolve(
    CommunicationAudience audience, {
    required CommunicationRole role,
  }) =>
      completer.future;
}

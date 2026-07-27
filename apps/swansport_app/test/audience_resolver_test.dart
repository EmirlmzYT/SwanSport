import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/data/fixtures/fixture_audience_resolver.dart';
import 'package:swansport_app/features/announcements/domain/models/audience_resolution.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  const resolver = FixtureAudienceResolver();

  Future<ResolvedAudience> resolve(
    AudienceSegment segment,
    String id, {
    CommunicationRole role = CommunicationRole.headCoach,
  }) async {
    final result = await resolver.resolve(
      CommunicationAudience(
        segments: {segment},
        recipientIds: {SwanId(id)},
      ),
      role: role,
    );
    expect(result, isA<AppSuccess<ResolvedAudience>>());
    return (result as AppSuccess<ResolvedAudience>).value;
  }

  test('resolves every real organizational scope deterministically', () async {
    expect(
      (await resolve(AudienceSegment.club, 'club')).totalUniqueRecipients,
      6,
    );
    expect(
      (await resolve(AudienceSegment.branch, 'basketball_branch'))
          .totalUniqueRecipients,
      5,
    );
    expect(
      (await resolve(AudienceSegment.team, 'u16')).totalUniqueRecipients,
      3,
    );
    expect(
      (await resolve(AudienceSegment.role, 'coaches')).totalUniqueRecipients,
      1,
    );
    expect(
      (await resolve(AudienceSegment.athlete, 'athlete_ali'))
          .totalUniqueRecipients,
      1,
    );
    expect(
      (await resolve(AudienceSegment.guardian, 'guardians'))
          .totalUniqueRecipients,
      2,
    );
  });

  test('mixed resolution removes overlaps and uses stable ordering', () async {
    const audience = CommunicationAudience(
      segments: {
        AudienceSegment.team,
        AudienceSegment.role,
        AudienceSegment.guardian,
        AudienceSegment.mixed,
      },
      recipientIds: {
        SwanId('u16'),
        SwanId('coaches'),
        SwanId('guardian_for_ali'),
        SwanId('guardian_for_deniz'),
      },
    );
    final first = (await resolver.resolve(
      audience,
      role: CommunicationRole.headCoach,
    ) as AppSuccess<ResolvedAudience>)
        .value;
    final second = (await resolver.resolve(
      audience,
      role: CommunicationRole.headCoach,
    ) as AppSuccess<ResolvedAudience>)
        .value;
    expect(first.recipientIds.map((id) => id.value), [
      'athlete_ali',
      'athlete_deniz',
      'guardian_ortak',
      'staff_coach',
    ]);
    expect(
      second.recipientIds.map((id) => id.value),
      first.recipientIds.map((id) => id.value),
    );
    expect(first.preview.total, 4);
    expect(first.preview.categoryCounts[AudienceRecipientCategory.guardian], 1);
    expect(first.preview.audienceLabels, isNotEmpty);
  });

  test('rejects empty and unsupported selections with typed failures',
      () async {
    final empty = await resolver.resolve(
      const CommunicationAudience(segments: {}, recipientIds: {}),
      role: CommunicationRole.headCoach,
    );
    expect(
      (empty as AppError<ResolvedAudience>).failure.code,
      'audience_empty',
    );
    final unsupported = await resolver.resolve(
      const CommunicationAudience(
        segments: {AudienceSegment.team},
        recipientIds: {SwanId('unknown_team')},
      ),
      role: CommunicationRole.headCoach,
    );
    expect(
      (unsupported as AppError<ResolvedAudience>).failure.code,
      'audience_unsupported',
    );
  });

  test('enforces group permission and recipient privacy outside widgets',
      () async {
    final restricted = await resolver.resolve(
      const CommunicationAudience(
        segments: {AudienceSegment.branch},
        recipientIds: {SwanId('restricted_branch')},
      ),
      role: CommunicationRole.headCoach,
    );
    expect(
      (restricted as AppError<ResolvedAudience>).failure.code,
      'audience_permission_denied',
    );
    for (final role in [
      CommunicationRole.athlete,
      CommunicationRole.guardian,
    ]) {
      final private = await resolver.resolve(
        const CommunicationAudience(
          segments: {AudienceSegment.club},
          recipientIds: {SwanId('club')},
        ),
        role: role,
      );
      expect(
        (private as AppError<ResolvedAudience>).failure.code,
        'audience_permission_denied',
      );
    }
  });

  test('fixture result exposes safe aggregate data only', () async {
    final result = await resolve(AudienceSegment.club, 'club');
    expect(result.preview.total, 6);
    expect(result.preview.categoryCounts.values.reduce((a, b) => a + b), 6);
    expect(result.preview.toString(), isNot(contains('@')));
    expect(result.preview.toString(), isNot(contains('+90')));
  });
}

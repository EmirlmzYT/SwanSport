import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../../domain/models/audience_resolution.dart';
import '../../domain/models/communication_center.dart';

class FixtureAudienceResolver implements AudienceResolver {
  const FixtureAudienceResolver();

  static const _recipients = <String, AudienceRecipientCategory>{
    'athlete_ali': AudienceRecipientCategory.athlete,
    'athlete_deniz': AudienceRecipientCategory.athlete,
    'guardian_kaya': AudienceRecipientCategory.guardian,
    'guardian_ortak': AudienceRecipientCategory.guardian,
    'staff_coach': AudienceRecipientCategory.staff,
    'staff_admin': AudienceRecipientCategory.staff,
  };

  static const _scopes = <AudienceSegment, Map<String, List<String>>>{
    AudienceSegment.club: {
      'club': [
        'athlete_ali',
        'athlete_deniz',
        'guardian_kaya',
        'guardian_ortak',
        'staff_coach',
        'staff_admin',
      ],
    },
    AudienceSegment.branch: {
      'basketball_branch': [
        'athlete_ali',
        'athlete_deniz',
        'guardian_kaya',
        'guardian_ortak',
        'staff_coach',
      ],
      'restricted_branch': ['staff_admin'],
    },
    AudienceSegment.team: {
      'u16': ['athlete_ali', 'athlete_deniz', 'staff_coach'],
    },
    AudienceSegment.role: {
      'coaches': ['staff_coach'],
      'guardians_role': ['guardian_kaya', 'guardian_ortak'],
    },
    AudienceSegment.athlete: {
      'athlete_ali': ['athlete_ali'],
      'athlete_deniz': ['athlete_deniz'],
    },
    AudienceSegment.guardian: {
      'guardians': ['guardian_kaya', 'guardian_ortak'],
      'guardian_kaya': ['guardian_kaya'],
      'guardian_for_ali': ['guardian_ortak'],
      'guardian_for_deniz': ['guardian_ortak'],
    },
  };

  @override
  Future<AppResult<ResolvedAudience>> resolve(
    CommunicationAudience audience, {
    required CommunicationRole role,
  }) async {
    if (audience.segments.isEmpty || audience.recipientIds.isEmpty) {
      return const AppError(
        AppFailure(
          code: 'audience_empty',
          message: 'En az bir hedef kitle seçilmelidir.',
        ),
      );
    }
    if (!_canResolve(role)) {
      return const AppError(
        AppFailure(
          code: 'audience_permission_denied',
          message: 'Bu rol hedef kitle alıcılarını çözümleyemez.',
        ),
      );
    }

    final resolved = <String, AudienceRecipientCategory>{};
    final labels = <String>[];
    var matchedSelection = false;
    for (final segment in audience.segments) {
      if (segment == AudienceSegment.mixed) continue;
      final scopes = _scopes[segment];
      if (scopes == null) {
        return const AppError(
          AppFailure(
            code: 'audience_unsupported',
            message: 'Hedef kitle türü desteklenmiyor.',
          ),
        );
      }
      for (final selectedId in audience.recipientIds) {
        final members = scopes[selectedId.value];
        if (members == null) continue;
        matchedSelection = true;
        if (selectedId.value == 'restricted_branch' &&
            role != CommunicationRole.superAdmin &&
            role != CommunicationRole.clubAdmin) {
          return const AppError(
            AppFailure(
              code: 'audience_permission_denied',
              message: 'Seçilen hedef kitle için yetkiniz yok.',
            ),
          );
        }
        labels.add(_label(segment, selectedId.value));
        for (final member in members) {
          resolved[member] = _recipients[member]!;
        }
      }
    }
    if (!matchedSelection) {
      return const AppError(
        AppFailure(
          code: 'audience_unsupported',
          message: 'Seçilen hedef kitle bulunamadı.',
        ),
      );
    }

    final orderedIds = resolved.keys.toList()..sort();
    final counts = <AudienceRecipientCategory, int>{};
    for (final id in orderedIds) {
      final category = resolved[id]!;
      counts[category] = (counts[category] ?? 0) + 1;
    }
    labels.sort();
    return AppSuccess(
      ResolvedAudience(
        recipientIds: orderedIds.map(SwanId.new).toList(growable: false),
        preview: AudienceRecipientPreview(
          total: orderedIds.length,
          categoryCounts: Map.unmodifiable(counts),
          audienceLabels: List.unmodifiable(labels),
        ),
      ),
    );
  }

  bool _canResolve(CommunicationRole role) =>
      role == CommunicationRole.superAdmin ||
      role == CommunicationRole.clubAdmin ||
      role == CommunicationRole.headCoach;

  String _label(AudienceSegment segment, String id) =>
      '${segment.name}: ${id.replaceAll('_', ' ')}';
}

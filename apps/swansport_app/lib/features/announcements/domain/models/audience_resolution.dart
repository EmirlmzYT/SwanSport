import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import 'communication_center.dart';

enum AudienceRecipientCategory { athlete, guardian, staff }

class AudienceRecipientPreview {
  const AudienceRecipientPreview({
    required this.total,
    required this.categoryCounts,
    required this.audienceLabels,
  });

  final int total;
  final Map<AudienceRecipientCategory, int> categoryCounts;
  final List<String> audienceLabels;
}

class ResolvedAudience {
  const ResolvedAudience({
    required this.recipientIds,
    required this.preview,
  });

  final List<SwanId> recipientIds;
  final AudienceRecipientPreview preview;
  int get totalUniqueRecipients => recipientIds.length;
}

abstract class AudienceResolver {
  Future<AppResult<ResolvedAudience>> resolve(
    CommunicationAudience audience, {
    required CommunicationRole role,
  });
}

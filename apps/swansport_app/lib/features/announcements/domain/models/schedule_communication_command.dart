import 'package:swansport_models/swansport_models.dart';

import '../../application/communication_composer_draft.dart';
import 'audience_resolution.dart';
import 'communication_center.dart';

class ScheduleCommunicationCommand {
  const ScheduleCommunicationCommand({
    required this.draft,
    required this.resolvedAudience,
    required this.type,
    required this.senderId,
    required this.now,
    required this.idempotencyKey,
  });

  final CommunicationComposerDraft draft;
  final ResolvedAudience resolvedAudience;
  final CommunicationType type;
  final SwanId senderId;
  final DateTime now;
  final String idempotencyKey;
}

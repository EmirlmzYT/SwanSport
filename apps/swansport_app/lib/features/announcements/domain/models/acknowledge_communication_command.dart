import 'package:swansport_models/swansport_models.dart';

import 'communication_center.dart';

class AcknowledgeCommunicationCommand {
  const AcknowledgeCommunicationCommand({
    required this.communicationId,
    required this.recipientId,
    required this.role,
    required this.acknowledgedAt,
  });

  final SwanId communicationId;
  final SwanId recipientId;
  final CommunicationRole role;
  final DateTime acknowledgedAt;
}

class CommunicationAcknowledgementResult {
  const CommunicationAcknowledgementResult({
    required this.item,
    required this.eligibleCount,
    required this.acknowledgedCount,
    required this.pendingCount,
    required this.overdueCount,
    required this.actingUserAcknowledged,
    required this.actingUserAcknowledgedAt,
  });

  final CommunicationItem item;
  final int eligibleCount;
  final int acknowledgedCount;
  final int pendingCount;
  final int overdueCount;
  final bool actingUserAcknowledged;
  final DateTime? actingUserAcknowledgedAt;
  bool get isFullyAcknowledged => pendingCount == 0;
}

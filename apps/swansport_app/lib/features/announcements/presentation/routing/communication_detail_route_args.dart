import 'package:swansport_models/swansport_models.dart';

import '../../domain/models/communication_center.dart';

class CommunicationDetailRouteArgs {
  const CommunicationDetailRouteArgs({
    required this.communicationId,
    this.role = CommunicationRole.headCoach,
    this.actingRecipientId = const SwanId('athlete_eligible'),
  });

  final SwanId communicationId;
  final CommunicationRole role;
  final SwanId actingRecipientId;
}

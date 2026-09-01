import 'package:swansport_models/swansport_models.dart';
import 'package:swansport_core/swansport_core.dart';

enum CommunicationType { announcement, bulletin, emergency }

enum CommunicationPriority { normal, high, emergency }

enum CommunicationStatus { draft, scheduled, published, cancelled, archived }

enum AudienceSegment { club, branch, team, athlete, guardian, role, mixed }

enum DeliveryStatus { queued, sent, delivered, read, acknowledged, failed }

enum AcknowledgementStatus { notRequired, pending, acknowledged, overdue }

enum AttachmentType { document, image, link }

enum CommunicationOperationalLinkType { athleteProfile }

class CommunicationOperationalLink {
  const CommunicationOperationalLink({
    required this.type,
    required this.targetId,
    required this.label,
    this.teamId,
    this.seasonId,
  });

  final CommunicationOperationalLinkType type;
  final SwanId targetId;
  final String label;
  final SwanId? teamId;
  final SwanId? seasonId;
}

enum CommunicationRole {
  superAdmin,
  clubAdmin,
  headCoach,
  assistantCoach,
  medicalStaff,
  athlete,
  guardian
}

class CommunicationAudience {
  const CommunicationAudience({
    required this.segments,
    required this.recipientIds,
  });
  final Set<AudienceSegment> segments;
  final Set<SwanId> recipientIds;
}

class RecipientSummary {
  const RecipientSummary({required this.total, required this.resolved});
  final int total;
  final int resolved;
}

class DeliverySummary {
  const DeliverySummary({
    required this.queued,
    required this.sent,
    required this.delivered,
    required this.read,
    required this.acknowledged,
    required this.failed,
  });
  final int queued;
  final int sent;
  final int delivered;
  final int read;
  final int acknowledged;
  final int failed;
}

class AcknowledgementSummary {
  const AcknowledgementSummary({
    required this.status,
    required this.required,
    required this.acknowledged,
  });
  final AcknowledgementStatus status;
  final int required;
  final int acknowledged;
}

class CommunicationAttachment {
  const CommunicationAttachment({
    required this.id,
    required this.type,
    required this.name,
  });
  final SwanId id;
  final AttachmentType type;
  final String name;
}

class CommunicationSchedule {
  const CommunicationSchedule({required this.publishAt});
  final DateTime publishAt;
}

class CommunicationAnalytics {
  const CommunicationAnalytics({
    required this.activeCount,
    required this.readRate,
    required this.pendingAcknowledgements,
    required this.scheduledCount,
  });
  final int activeCount;
  final int readRate;
  final int pendingAcknowledgements;
  final int scheduledCount;
}

class CommunicationPermissionSet {
  const CommunicationPermissionSet({
    required this.canCompose,
    required this.canPublish,
    required this.canSchedule,
    required this.canAcknowledge,
    required this.canSendEmergency,
    required this.canViewDelivery,
    required this.canAttach,
  });
  final bool canCompose;
  final bool canPublish;
  final bool canSchedule;
  final bool canAcknowledge;
  final bool canSendEmergency;
  final bool canViewDelivery;
  final bool canAttach;
}

class CommunicationFilterState {
  const CommunicationFilterState({this.types = const {}, this.query = ''});
  final Set<CommunicationType> types;
  final String query;
  bool matches(CommunicationItem item) {
    if (types.isNotEmpty && !types.contains(item.type)) return false;
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return [item.title, item.body, item.sender]
        .any((value) => trContains(value, normalizedQuery));
  }
}

class CommunicationItem {
  const CommunicationItem({
    required this.id,
    required this.type,
    required this.priority,
    required this.status,
    required this.title,
    required this.body,
    required this.audience,
    required this.recipients,
    required this.delivery,
    required this.acknowledgement,
    required this.attachments,
    required this.publishedAt,
    this.sender = '',
    this.schedule,
    this.isPinned = false,
    this.operationalLinks = const [],
  });
  final SwanId id;
  final CommunicationType type;
  final CommunicationPriority priority;
  final CommunicationStatus status;
  final String title;
  final String body;
  final CommunicationAudience audience;
  final RecipientSummary recipients;
  final DeliverySummary delivery;
  final AcknowledgementSummary acknowledgement;
  final List<CommunicationAttachment> attachments;
  final DateTime publishedAt;
  final String sender;
  final CommunicationSchedule? schedule;
  final bool isPinned;
  final List<CommunicationOperationalLink> operationalLinks;
  CommunicationItem copyWith({
    DeliverySummary? delivery,
    AcknowledgementSummary? acknowledgement,
  }) =>
      CommunicationItem(
        id: id,
        type: type,
        priority: priority,
        status: status,
        title: title,
        body: body,
        audience: audience,
        recipients: recipients,
        delivery: delivery ?? this.delivery,
        acknowledgement: acknowledgement ?? this.acknowledgement,
        attachments: attachments,
        publishedAt: publishedAt,
        sender: sender,
        schedule: schedule,
        isPinned: isPinned,
        operationalLinks: operationalLinks,
      );
}

class CommunicationWorkspace {
  const CommunicationWorkspace({
    required this.items,
    required this.analytics,
    required this.permissions,
    this.isOffline = false,
    this.isStale = false,
    this.sectionFailures = const {},
  });
  final List<CommunicationItem> items;
  final CommunicationAnalytics? analytics;
  final CommunicationPermissionSet permissions;
  final bool isOffline;
  final bool isStale;
  final Map<String, String> sectionFailures;
}

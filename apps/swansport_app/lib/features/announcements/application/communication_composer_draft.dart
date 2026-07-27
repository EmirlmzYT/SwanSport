import '../domain/models/communication_center.dart';

class CommunicationComposerDraft {
  const CommunicationComposerDraft({
    this.title = '',
    this.body = '',
    this.priority = CommunicationPriority.normal,
    this.type = CommunicationType.announcement,
    this.audience = const CommunicationAudience(segments: {}, recipientIds: {}),
    this.attachments = const [],
    this.requiresAcknowledgement = false,
    this.schedule,
  });
  final String title;
  final String body;
  final CommunicationPriority priority;
  final CommunicationType type;
  final CommunicationAudience audience;
  final List<CommunicationAttachment> attachments;
  final bool requiresAcknowledgement;
  final CommunicationSchedule? schedule;
  CommunicationComposerDraft copyWith({
    String? title,
    String? body,
    CommunicationPriority? priority,
    CommunicationType? type,
    CommunicationAudience? audience,
    List<CommunicationAttachment>? attachments,
    bool? requiresAcknowledgement,
    CommunicationSchedule? schedule,
  }) =>
      CommunicationComposerDraft(
        title: title ?? this.title,
        body: body ?? this.body,
        priority: priority ?? this.priority,
        type: type ?? this.type,
        audience: audience ?? this.audience,
        attachments: attachments ?? this.attachments,
        requiresAcknowledgement:
            requiresAcknowledgement ?? this.requiresAcknowledgement,
        schedule: schedule ?? this.schedule,
      );
  String? get validationError => title.trim().isEmpty
      ? 'Başlık gereklidir.'
      : body.trim().isEmpty
          ? 'İçerik gereklidir.'
          : audience.recipientIds.isEmpty
              ? 'Geçerli bir hedef kitle gereklidir.'
              : null;
}

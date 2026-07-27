import 'package:swansport_models/swansport_models.dart';
import '../../domain/models/communication_center.dart';

class FixtureCommunicationCenterDataSource {
  const FixtureCommunicationCenterDataSource();
  List<CommunicationItem> get items => [
        CommunicationItem(
          id: const SwanId('communication_facility'),
          type: CommunicationType.announcement,
          priority: CommunicationPriority.high,
          status: CommunicationStatus.published,
          title: 'Tesis Bakım Çalışması Hakkında',
          body: 'Salon B bakımdadır. Antrenmanlar Salon A’ya taşınmıştır.',
          audience: const CommunicationAudience(
            segments: {AudienceSegment.team},
            recipientIds: {SwanId('u16')},
          ),
          recipients: const RecipientSummary(total: 48, resolved: 48),
          delivery: const DeliverySummary(
            queued: 0,
            sent: 48,
            delivered: 47,
            read: 45,
            acknowledged: 0,
            failed: 1,
          ),
          acknowledgement: const AcknowledgementSummary(
            status: AcknowledgementStatus.notRequired,
            required: 0,
            acknowledged: 0,
          ),
          attachments: const [],
          publishedAt: DateTime(2026, 7, 22),
          sender: 'Kulüp Yönetimi',
          isPinned: true,
          operationalLinks: const [
            CommunicationOperationalLink(
              type: CommunicationOperationalLinkType.athleteProfile,
              targetId: SwanId('athlete_can_yilmaz'),
              label: 'Can Yılmaz profilini görüntüle',
              teamId: SwanId('team_u16_male'),
              seasonId: SwanId('season_2025_2026'),
            ),
          ],
        ),
        CommunicationItem(
          id: const SwanId('communication_emergency'),
          type: CommunicationType.emergency,
          priority: CommunicationPriority.emergency,
          status: CommunicationStatus.published,
          title: 'Acil Durum Uyarısı',
          body: 'Tesis giriş prosedürü güncellenmiştir.',
          audience: const CommunicationAudience(
            segments: {AudienceSegment.club},
            recipientIds: {SwanId('club')},
          ),
          recipients: const RecipientSummary(total: 48, resolved: 48),
          delivery: const DeliverySummary(
            queued: 0,
            sent: 48,
            delivered: 48,
            read: 42,
            acknowledged: 42,
            failed: 0,
          ),
          acknowledgement: const AcknowledgementSummary(
            status: AcknowledgementStatus.pending,
            required: 48,
            acknowledged: 42,
          ),
          attachments: const [],
          publishedAt: DateTime(2026, 7, 22),
          sender: 'Güvenlik Birimi',
        ),
        CommunicationItem(
          id: const SwanId('communication_schedule'),
          type: CommunicationType.bulletin,
          priority: CommunicationPriority.normal,
          status: CommunicationStatus.scheduled,
          title: 'Sezon Bilgilendirmesi',
          body: 'Planlanan kulüp bülteni.',
          audience: const CommunicationAudience(
            segments: {AudienceSegment.guardian},
            recipientIds: {SwanId('guardians')},
          ),
          recipients: const RecipientSummary(total: 48, resolved: 48),
          delivery: const DeliverySummary(
            queued: 48,
            sent: 0,
            delivered: 0,
            read: 0,
            acknowledged: 0,
            failed: 0,
          ),
          acknowledgement: const AcknowledgementSummary(
            status: AcknowledgementStatus.pending,
            required: 48,
            acknowledged: 0,
          ),
          attachments: const [
            CommunicationAttachment(
              id: SwanId('attachment_consent'),
              type: AttachmentType.document,
              name: 'Veli Muvafakatnamesi.pdf',
            ),
          ],
          publishedAt: DateTime(2026, 7, 23),
          sender: 'Baş Antrenör',
          schedule: CommunicationSchedule(publishAt: DateTime(2026, 7, 24, 9)),
        ),
        CommunicationItem(
          id: const SwanId('communication_cancelled'),
          type: CommunicationType.announcement,
          priority: CommunicationPriority.normal,
          status: CommunicationStatus.cancelled,
          title: 'İptal Edilen Duyuru',
          body: 'Bu ileti artık kullanılamaz.',
          audience: const CommunicationAudience(
            segments: {AudienceSegment.club},
            recipientIds: {SwanId('club')},
          ),
          recipients: const RecipientSummary(total: 1, resolved: 1),
          delivery: const DeliverySummary(
            queued: 0,
            sent: 0,
            delivered: 0,
            read: 0,
            acknowledged: 0,
            failed: 0,
          ),
          acknowledgement: const AcknowledgementSummary(
            status: AcknowledgementStatus.pending,
            required: 1,
            acknowledged: 0,
          ),
          attachments: const [],
          publishedAt: DateTime(2026, 7, 20),
          sender: 'Kulüp Yönetimi',
        ),
      ];
  CommunicationAnalytics get analytics => const CommunicationAnalytics(
        activeCount: 14,
        readRate: 92,
        pendingAcknowledgements: 3,
        scheduledCount: 2,
      );
}

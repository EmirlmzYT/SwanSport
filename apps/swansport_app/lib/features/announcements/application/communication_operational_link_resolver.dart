import '../domain/models/communication_center.dart';

class CommunicationOperationalLinkResolver {
  const CommunicationOperationalLinkResolver();

  List<CommunicationOperationalLink> resolve({
    required CommunicationItem item,
    required CommunicationRole role,
  }) {
    if (item.status == CommunicationStatus.cancelled ||
        item.status == CommunicationStatus.archived) {
      return const [];
    }

    final canViewAthletes = switch (role) {
      CommunicationRole.superAdmin ||
      CommunicationRole.clubAdmin ||
      CommunicationRole.headCoach ||
      CommunicationRole.assistantCoach ||
      CommunicationRole.medicalStaff =>
        true,
      CommunicationRole.athlete || CommunicationRole.guardian => false,
    };

    return item.operationalLinks
        .where(
          (link) =>
              !link.targetId.isEmpty &&
              link.label.trim().isNotEmpty &&
              switch (link.type) {
                CommunicationOperationalLinkType.athleteProfile =>
                  canViewAthletes,
              },
        )
        .toList(growable: false);
  }
}

import '../domain/models/communication_center.dart';

class CommunicationCenterPermissions {
  const CommunicationCenterPermissions._();
  static CommunicationPermissionSet forRole(CommunicationRole role) =>
      switch (role) {
        CommunicationRole.superAdmin ||
        CommunicationRole.clubAdmin =>
          const CommunicationPermissionSet(
            canCompose: true,
            canPublish: true,
            canSchedule: true,
            canAcknowledge: false,
            canSendEmergency: true,
            canViewDelivery: true,
            canAttach: true,
          ),
        CommunicationRole.headCoach => const CommunicationPermissionSet(
            canCompose: true,
            canPublish: true,
            canSchedule: true,
            canAcknowledge: false,
            canSendEmergency: false,
            canViewDelivery: true,
            canAttach: true,
          ),
        CommunicationRole.assistantCoach => const CommunicationPermissionSet(
            canCompose: false,
            canPublish: false,
            canSchedule: false,
            canAcknowledge: false,
            canSendEmergency: false,
            canViewDelivery: false,
            canAttach: false,
          ),
        CommunicationRole.medicalStaff => const CommunicationPermissionSet(
            canCompose: false,
            canPublish: false,
            canSchedule: false,
            canAcknowledge: false,
            canSendEmergency: false,
            canViewDelivery: false,
            canAttach: false,
          ),
        _ => const CommunicationPermissionSet(
            canCompose: false,
            canPublish: false,
            canSchedule: false,
            canAcknowledge: true,
            canSendEmergency: false,
            canViewDelivery: false,
            canAttach: false,
          )
      };
}

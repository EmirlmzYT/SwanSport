import '../domain/models/acknowledge_communication_command.dart';
import '../domain/models/communication_center.dart';
import 'communication_center_state.dart';

enum CommunicationDetailStatus {
  loading,
  loaded,
  notFound,
  permissionDenied,
  offlineCached,
  failure,
  unavailable,
  invalidRoute,
}

class CommunicationDetailState {
  const CommunicationDetailState({
    required this.status,
    required this.role,
    required this.permissions,
    this.item,
    this.errorMessage,
    this.acknowledgementOperationStatus =
        CommunicationAcknowledgementOperationStatus.idle,
    this.acknowledgementResult,
    this.acknowledgementError,
    this.isLinkedNavigationPending = false,
  });

  factory CommunicationDetailState.loading(CommunicationRole role) =>
      CommunicationDetailState(
        status: CommunicationDetailStatus.loading,
        role: role,
        permissions: const CommunicationPermissionSet(
          canCompose: false,
          canPublish: false,
          canSchedule: false,
          canAcknowledge: false,
          canSendEmergency: false,
          canViewDelivery: false,
          canAttach: false,
        ),
      );

  final CommunicationDetailStatus status;
  final CommunicationRole role;
  final CommunicationPermissionSet permissions;
  final CommunicationItem? item;
  final String? errorMessage;
  final CommunicationAcknowledgementOperationStatus
      acknowledgementOperationStatus;
  final CommunicationAcknowledgementResult? acknowledgementResult;
  final String? acknowledgementError;
  final bool isLinkedNavigationPending;

  CommunicationDetailState copyWith({
    CommunicationDetailStatus? status,
    CommunicationPermissionSet? permissions,
    CommunicationItem? item,
    String? errorMessage,
    CommunicationAcknowledgementOperationStatus? acknowledgementOperationStatus,
    CommunicationAcknowledgementResult? acknowledgementResult,
    String? acknowledgementError,
    bool clearAcknowledgement = false,
    bool? isLinkedNavigationPending,
  }) =>
      CommunicationDetailState(
        status: status ?? this.status,
        role: role,
        permissions: permissions ?? this.permissions,
        item: item ?? this.item,
        errorMessage: errorMessage ?? this.errorMessage,
        acknowledgementOperationStatus: acknowledgementOperationStatus ??
            this.acknowledgementOperationStatus,
        acknowledgementResult: acknowledgementResult ??
            (clearAcknowledgement ? null : this.acknowledgementResult),
        acknowledgementError: acknowledgementError ??
            (clearAcknowledgement ? null : this.acknowledgementError),
        isLinkedNavigationPending:
            isLinkedNavigationPending ?? this.isLinkedNavigationPending,
      );
}

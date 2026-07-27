import '../domain/models/acknowledge_communication_command.dart';
import '../domain/models/audience_resolution.dart';
import '../domain/models/communication_center.dart';
import 'communication_composer_draft.dart';

enum CommunicationCenterStatus { loading, loaded, empty, error }

enum AudienceResolutionStatus {
  idle,
  resolving,
  resolved,
  validationFailure,
  permissionFailure,
  repositoryFailure,
}

enum CommunicationSchedulingStatus {
  idle,
  validating,
  scheduling,
  success,
  validationFailure,
  permissionFailure,
  offlineFailure,
  repositoryFailure,
}

enum CommunicationAcknowledgementOperationStatus {
  idle,
  submitting,
  success,
  validationFailure,
  permissionFailure,
  offlineFailure,
  repositoryFailure,
}

class CommunicationCenterState {
  const CommunicationCenterState({
    required this.status,
    required this.role,
    required this.filters,
    required this.permissions,
    this.workspace,
    this.selected,
    this.errorMessage,
    this.searchQuery = '',
    this.composerDraft = const CommunicationComposerDraft(),
    this.audienceResolutionStatus = AudienceResolutionStatus.idle,
    this.resolvedAudience,
    this.audienceResolutionError,
    this.schedulingStatus = CommunicationSchedulingStatus.idle,
    this.scheduledItem,
    this.schedulingError,
    this.acknowledgementOperationStatus =
        CommunicationAcknowledgementOperationStatus.idle,
    this.acknowledgementResult,
    this.acknowledgementError,
    this.acknowledgementCommunicationId,
  });
  factory CommunicationCenterState.loading({
    CommunicationRole role = CommunicationRole.headCoach,
  }) =>
      CommunicationCenterState(
        status: CommunicationCenterStatus.loading,
        role: role,
        filters: const CommunicationFilterState(),
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
  final CommunicationCenterStatus status;
  final CommunicationRole role;
  final CommunicationFilterState filters;
  final CommunicationPermissionSet permissions;
  final CommunicationWorkspace? workspace;
  final CommunicationItem? selected;
  final String? errorMessage;
  final String searchQuery;
  final CommunicationComposerDraft composerDraft;
  final AudienceResolutionStatus audienceResolutionStatus;
  final ResolvedAudience? resolvedAudience;
  final String? audienceResolutionError;
  final CommunicationSchedulingStatus schedulingStatus;
  final CommunicationItem? scheduledItem;
  final String? schedulingError;
  final CommunicationAcknowledgementOperationStatus
      acknowledgementOperationStatus;
  final CommunicationAcknowledgementResult? acknowledgementResult;
  final String? acknowledgementError;
  final String? acknowledgementCommunicationId;
  CommunicationCenterState copyWith({
    CommunicationCenterStatus? status,
    CommunicationFilterState? filters,
    CommunicationPermissionSet? permissions,
    CommunicationWorkspace? workspace,
    CommunicationItem? selected,
    String? errorMessage,
    String? searchQuery,
    CommunicationComposerDraft? composerDraft,
    AudienceResolutionStatus? audienceResolutionStatus,
    ResolvedAudience? resolvedAudience,
    String? audienceResolutionError,
    bool clearAudienceResolution = false,
    CommunicationSchedulingStatus? schedulingStatus,
    CommunicationItem? scheduledItem,
    String? schedulingError,
    bool clearSchedulingResult = false,
    CommunicationAcknowledgementOperationStatus? acknowledgementOperationStatus,
    CommunicationAcknowledgementResult? acknowledgementResult,
    String? acknowledgementError,
    String? acknowledgementCommunicationId,
    bool clearAcknowledgementOperation = false,
  }) =>
      CommunicationCenterState(
        status: status ?? this.status,
        role: role,
        filters: filters ?? this.filters,
        permissions: permissions ?? this.permissions,
        workspace: workspace ?? this.workspace,
        selected: selected ?? this.selected,
        errorMessage: errorMessage ?? this.errorMessage,
        searchQuery: searchQuery ?? this.searchQuery,
        composerDraft: composerDraft ?? this.composerDraft,
        audienceResolutionStatus:
            audienceResolutionStatus ?? this.audienceResolutionStatus,
        resolvedAudience: resolvedAudience ??
            (clearAudienceResolution ? null : this.resolvedAudience),
        audienceResolutionError: audienceResolutionError ??
            (clearAudienceResolution ? null : this.audienceResolutionError),
        schedulingStatus: schedulingStatus ?? this.schedulingStatus,
        scheduledItem: scheduledItem ??
            (clearSchedulingResult ? null : this.scheduledItem),
        schedulingError: schedulingError ??
            (clearSchedulingResult ? null : this.schedulingError),
        acknowledgementOperationStatus: acknowledgementOperationStatus ??
            this.acknowledgementOperationStatus,
        acknowledgementResult: acknowledgementResult ??
            (clearAcknowledgementOperation ? null : this.acknowledgementResult),
        acknowledgementError: acknowledgementError ??
            (clearAcknowledgementOperation ? null : this.acknowledgementError),
        acknowledgementCommunicationId: acknowledgementCommunicationId ??
            (clearAcknowledgementOperation
                ? null
                : this.acknowledgementCommunicationId),
      );
}

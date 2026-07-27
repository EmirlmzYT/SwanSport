import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';

import '../domain/models/acknowledge_communication_command.dart';
import '../domain/models/communication_center.dart';
import '../domain/repositories/communication_center_repository.dart';
import '../presentation/routing/communication_detail_route_args.dart';
import 'communication_center_controller.dart';
import 'communication_center_permissions.dart';
import 'communication_center_state.dart';
import 'communication_detail_state.dart';
import 'communication_operational_link_resolver.dart';

class CommunicationDetailRequest {
  const CommunicationDetailRequest({
    required this.args,
    this.scenario = CommunicationFixtureScenario.normal,
  });

  final CommunicationDetailRouteArgs args;
  final CommunicationFixtureScenario scenario;
}

final communicationDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<CommunicationDetailController, CommunicationDetailState,
        CommunicationDetailRequest>(
  (ref, request) => CommunicationDetailController(
    repository: ref.watch(communicationCenterRepositoryProvider),
    args: request.args,
    scenario: request.scenario,
  ),
);

class CommunicationDetailController
    extends StateNotifier<CommunicationDetailState> {
  CommunicationDetailController({
    required CommunicationCenterRepository repository,
    required CommunicationDetailRouteArgs args,
    CommunicationFixtureScenario scenario = CommunicationFixtureScenario.normal,
    CommunicationClock clock = DateTime.now,
    CommunicationOperationalLinkResolver linkResolver =
        const CommunicationOperationalLinkResolver(),
  })  : _repository = repository,
        _args = args,
        _scenario = scenario,
        _clock = clock,
        _linkResolver = linkResolver,
        super(CommunicationDetailState.loading(args.role)) {
    load();
  }

  final CommunicationCenterRepository _repository;
  final CommunicationDetailRouteArgs _args;
  final CommunicationFixtureScenario _scenario;
  final CommunicationClock _clock;
  final CommunicationOperationalLinkResolver _linkResolver;
  int _loadRequest = 0;
  int _acknowledgementRequest = 0;

  List<CommunicationOperationalLink> get operationalLinks {
    final item = state.item;
    if (item == null) return const [];
    return _linkResolver.resolve(item: item, role: state.role);
  }

  bool beginLinkedNavigation(CommunicationOperationalLink link) {
    if (state.isLinkedNavigationPending || !operationalLinks.contains(link)) {
      return false;
    }
    state = state.copyWith(isLinkedNavigationPending: true);
    return true;
  }

  void completeLinkedNavigation() {
    if (state.isLinkedNavigationPending) {
      state = state.copyWith(isLinkedNavigationPending: false);
    }
  }

  Future<void> load() async {
    final request = ++_loadRequest;
    final result = await _repository.getDetail(
      _args.communicationId,
      role: _args.role,
      scenario: _scenario,
    );
    if (request != _loadRequest) return;
    final permissions = CommunicationCenterPermissions.forRole(_args.role);
    switch (result) {
      case AppSuccess<CommunicationItem>(value: final item):
        state = state.copyWith(
          status: item.status == CommunicationStatus.cancelled ||
                  item.status == CommunicationStatus.archived
              ? CommunicationDetailStatus.unavailable
              : _scenario == CommunicationFixtureScenario.offline
                  ? CommunicationDetailStatus.offlineCached
                  : CommunicationDetailStatus.loaded,
          item: item,
          permissions: permissions,
        );
      case AppError<CommunicationItem>(failure: final failure):
        state = state.copyWith(
          status: switch (failure.code) {
            'communication_not_found' => CommunicationDetailStatus.notFound,
            'communication_detail_permission_denied' =>
              CommunicationDetailStatus.permissionDenied,
            _ => CommunicationDetailStatus.failure,
          },
          permissions: permissions,
          errorMessage: failure.message,
        );
    }
  }

  bool get canAcknowledge {
    final item = state.item;
    return item != null &&
        state.permissions.canAcknowledge &&
        item.status == CommunicationStatus.published &&
        item.acknowledgement.status != AcknowledgementStatus.notRequired;
  }

  Future<void> acknowledge() async {
    if (state.acknowledgementOperationStatus ==
        CommunicationAcknowledgementOperationStatus.submitting) {
      return;
    }
    final item = state.item;
    if (item == null || !canAcknowledge) {
      state = state.copyWith(
        acknowledgementOperationStatus:
            CommunicationAcknowledgementOperationStatus.validationFailure,
        acknowledgementError: 'Bu ileti şu anda onaylanamaz.',
        clearAcknowledgement: true,
      );
      return;
    }
    if (_scenario == CommunicationFixtureScenario.offline) {
      state = state.copyWith(
        acknowledgementOperationStatus:
            CommunicationAcknowledgementOperationStatus.offlineFailure,
        acknowledgementError: 'Çevrimdışıyken ileti onaylanamaz.',
        clearAcknowledgement: true,
      );
      return;
    }
    final request = ++_acknowledgementRequest;
    state = state.copyWith(
      acknowledgementOperationStatus:
          CommunicationAcknowledgementOperationStatus.submitting,
      clearAcknowledgement: true,
    );
    final result = await _repository.acknowledge(
      AcknowledgeCommunicationCommand(
        communicationId: item.id,
        recipientId: _args.actingRecipientId,
        role: _args.role,
        acknowledgedAt: _clock(),
      ),
      scenario: _scenario,
    );
    if (request != _acknowledgementRequest) return;
    switch (result) {
      case AppSuccess<CommunicationAcknowledgementResult>(
          value: final acknowledgement,
        ):
        state = state.copyWith(
          item: acknowledgement.item,
          acknowledgementOperationStatus:
              CommunicationAcknowledgementOperationStatus.success,
          acknowledgementResult: acknowledgement,
          clearAcknowledgement: true,
        );
      case AppError<CommunicationAcknowledgementResult>(
          failure: final failure,
        ):
        state = state.copyWith(
          acknowledgementOperationStatus: switch (failure.code) {
            'acknowledgement_permission_denied' ||
            'acknowledgement_ineligible' =>
              CommunicationAcknowledgementOperationStatus.permissionFailure,
            'acknowledgement_offline' =>
              CommunicationAcknowledgementOperationStatus.offlineFailure,
            'acknowledgement_not_required' ||
            'acknowledgement_unavailable' =>
              CommunicationAcknowledgementOperationStatus.validationFailure,
            _ => CommunicationAcknowledgementOperationStatus.repositoryFailure,
          },
          acknowledgementError: failure.message,
          clearAcknowledgement: true,
        );
    }
  }
}

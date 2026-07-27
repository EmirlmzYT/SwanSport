import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../data/fixtures/athlete_detail_fixture_data_source.dart';
import '../data/repositories/fixture_athlete_detail_repository.dart';
import '../domain/models/athlete_detail.dart';
import '../domain/repositories/athlete_detail_repository.dart';
import 'athlete_detail_permissions.dart';
import 'athlete_detail_state.dart';

final athleteDetailFixtureDataSourceProvider =
    Provider<AthleteDetailFixtureDataSource>(
  (ref) => const AthleteDetailFixtureDataSource(),
);

final athleteDetailRepositoryProvider = Provider<AthleteDetailRepository>(
  (ref) => FixtureAthleteDetailRepository(
    ref.watch(athleteDetailFixtureDataSourceProvider),
  ),
);

final athleteDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<AthleteDetailController, AthleteDetailState, SwanId>(
  (ref, athleteId) {
    return AthleteDetailController(
      athleteId: athleteId,
      repository: ref.watch(athleteDetailRepositoryProvider),
    );
  },
);

class AthleteDetailController extends StateNotifier<AthleteDetailState> {
  AthleteDetailController({
    required SwanId athleteId,
    required AthleteDetailRepository repository,
    AthleteDetailRole role = AthleteDetailRole.coach,
  })  : _repository = repository,
        _role = role,
        super(AthleteDetailState.loading(athleteId: athleteId, role: role)) {
    load();
  }

  final AthleteDetailRepository _repository;
  final AthleteDetailRole _role;

  Future<void> load() async {
    state = AthleteDetailState.loading(athleteId: state.athleteId, role: _role);

    final result = await _repository.getAthleteDetail(state.athleteId);

    switch (result) {
      case AppSuccess<AthleteDetail>(value: final detail):
        final permissions = AthleteDetailPermissions.forRole(_role);
        state = state.copyWith(
          status: AthleteDetailStatus.loaded,
          detail: _filterDetailForPermissions(detail, permissions),
          permissions: permissions,
          lastSyncedLabel: detail.lastSyncedLabel,
        );
      case AppError<AthleteDetail>(failure: final failure):
        state = state.copyWith(
          status: _statusForFailure(failure),
          errorMessage: failure.message,
        );
    }
  }

  Future<void> refresh() => load();

  void selectSection(AthleteDetailSection section) {
    if (!state.permissions.canView(section)) {
      return;
    }

    state = state.copyWith(selectedSection: section);
  }

  AthleteDetailStatus _statusForFailure(AppFailure failure) {
    return switch (failure.code) {
      'athlete_not_found' => AthleteDetailStatus.notFound,
      'athlete_permission_denied' => AthleteDetailStatus.permissionDenied,
      _ => AthleteDetailStatus.error,
    };
  }

  AthleteDetail _filterDetailForPermissions(
    AthleteDetail detail,
    AthleteDetailPermissions permissions,
  ) {
    return detail.copyWith(
      documents: permissions.canView(AthleteDetailSection.documents)
          ? detail.documents
          : const [],
      notes: permissions.canView(AthleteDetailSection.notes)
          ? detail.notes
          : const [],
      timeline: permissions.canView(AthleteDetailSection.notes)
          ? detail.timeline
          : detail.timeline
              .where((entry) => entry.type != AthleteTimelineEntryType.note)
              .toList(growable: false),
    );
  }
}

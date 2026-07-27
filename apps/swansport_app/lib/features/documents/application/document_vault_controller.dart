import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';

import '../data/fixture_document_repository.dart';
import '../domain/models/document_vault.dart';
import 'document_permissions.dart';

enum DocumentVaultStatus {
  loading,
  loaded,
  empty,
  offline,
  failure,
  permissionDenied
}

class DocumentVaultState {
  const DocumentVaultState({
    this.status = DocumentVaultStatus.loading,
    this.documents = const [],
    this.filter = const DocumentFilter(),
    this.overview,
    this.storage,
    this.requests = const [],
    required this.permissions,
    this.error,
  });
  final DocumentVaultStatus status;
  final List<VaultDocument> documents;
  final DocumentFilter filter;
  final VaultOverview? overview;
  final StorageOverview? storage;
  final List<DocumentRequest> requests;
  final DocumentPermissionSet permissions;
  final String? error;

  List<VaultDocument> get filtered =>
      documents.where(filter.matches).toList(growable: false);

  DocumentVaultState copyWith({
    DocumentVaultStatus? status,
    List<VaultDocument>? documents,
    DocumentFilter? filter,
    VaultOverview? overview,
    StorageOverview? storage,
    List<DocumentRequest>? requests,
    String? error,
  }) =>
      DocumentVaultState(
        status: status ?? this.status,
        documents: documents ?? this.documents,
        filter: filter ?? this.filter,
        overview: overview ?? this.overview,
        storage: storage ?? this.storage,
        requests: requests ?? this.requests,
        permissions: permissions,
        error: error ?? this.error,
      );
}

final documentRepositoryProvider = Provider<FixtureDocumentRepository>(
  (ref) => FixtureDocumentRepository(),
);

final documentVaultControllerProvider = StateNotifierProvider.autoDispose<
    DocumentVaultController, DocumentVaultState>(
  (ref) => DocumentVaultController(
    repository: ref.watch(documentRepositoryProvider),
  ),
);

class DocumentVaultController extends StateNotifier<DocumentVaultState> {
  DocumentVaultController({
    required FixtureDocumentRepository repository,
    DocumentRole role = DocumentRole.coach,
    DocumentFixtureScenario scenario = DocumentFixtureScenario.normal,
  })  : _repository = repository,
        _scenario = scenario,
        super(
          DocumentVaultState(
            permissions: DocumentPermissions.forRole(role),
          ),
        ) {
    load();
  }
  final FixtureDocumentRepository _repository;
  final DocumentFixtureScenario _scenario;

  Future<void> load() async {
    if (!state.permissions.canView) {
      state = state.copyWith(status: DocumentVaultStatus.permissionDenied);
      return;
    }
    final result = await _repository.list(scenario: _scenario);
    switch (result) {
      case AppSuccess<List<VaultDocument>>(value: final documents):
        state = state.copyWith(
          status: _scenario == DocumentFixtureScenario.offline
              ? DocumentVaultStatus.offline
              : documents.isEmpty
                  ? DocumentVaultStatus.empty
                  : DocumentVaultStatus.loaded,
          documents: documents,
          overview: _repository.overview(documents),
          storage: _repository.storage,
          requests: await _repository.requests(),
        );
      case AppError<List<VaultDocument>>(failure: final failure):
        state = state.copyWith(
          status: DocumentVaultStatus.failure,
          error: failure.message,
        );
    }
  }

  void search(String query) =>
      state = state.copyWith(filter: state.filter.copyWith(query: query));
  void resetSearch() =>
      state = state.copyWith(filter: state.filter.copyWith(query: ''));
  void selectCategory(DocumentCategory? category) => state = state.copyWith(
        filter: state.filter.copyWith(
          category: category,
          clearCategory: category == null,
        ),
      );
  void toggleFavorites() => state = state.copyWith(
        filter: state.filter.copyWith(
          favoritesOnly: !state.filter.favoritesOnly,
        ),
      );
  void togglePinned() => state = state.copyWith(
        filter: state.filter.copyWith(pinnedOnly: !state.filter.pinnedOnly),
      );

  Future<void> createRequest(
    String title,
    String athlete,
    DateTime dueAt,
  ) async {
    if (!state.permissions.canManageRequests) return;
    await _repository.createRequest(
      title: title,
      athlete: athlete,
      dueAt: dueAt,
    );
    state = state.copyWith(requests: await _repository.requests());
  }

  Future<void> setRequestStatus(
    DocumentRequest request,
    DocumentRequestStatus status,
  ) async {
    if (!state.permissions.canManageRequests) return;
    await _repository.updateRequest(request.id, status);
    state = state.copyWith(requests: await _repository.requests());
  }
}

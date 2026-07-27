import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../data/fixture_document_repository.dart';
import '../domain/models/document_vault.dart';
import 'document_permissions.dart';
import 'document_vault_controller.dart';

enum DocumentDetailStatus {
  loading,
  loaded,
  notFound,
  permissionDenied,
  unavailable
}

class DocumentDetailState {
  const DocumentDetailState({
    this.status = DocumentDetailStatus.loading,
    this.document,
    required this.permissions,
  });
  final DocumentDetailStatus status;
  final VaultDocument? document;
  final DocumentPermissionSet permissions;
}

final documentDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<DocumentDetailController, DocumentDetailState, SwanId>(
  (ref, id) => DocumentDetailController(
    id: id,
    repository: ref.watch(documentRepositoryProvider),
  ),
);

class DocumentDetailController extends StateNotifier<DocumentDetailState> {
  DocumentDetailController({
    required SwanId id,
    required FixtureDocumentRepository repository,
    DocumentRole role = DocumentRole.coach,
  })  : _id = id,
        _repository = repository,
        super(
          DocumentDetailState(
            permissions: DocumentPermissions.forRole(role),
          ),
        ) {
    load();
  }
  final SwanId _id;
  final FixtureDocumentRepository _repository;

  Future<void> load() async {
    if (!state.permissions.canView) {
      state = DocumentDetailState(
        status: DocumentDetailStatus.permissionDenied,
        permissions: state.permissions,
      );
      return;
    }
    final result = await _repository.detail(_id);
    switch (result) {
      case AppSuccess<VaultDocument>(value: final document):
        state = DocumentDetailState(
          status: document.status == DocumentStatus.unavailable
              ? DocumentDetailStatus.unavailable
              : DocumentDetailStatus.loaded,
          document: document,
          permissions: state.permissions,
        );
      case AppError<VaultDocument>():
        state = DocumentDetailState(
          status: DocumentDetailStatus.notFound,
          permissions: state.permissions,
        );
    }
  }
}

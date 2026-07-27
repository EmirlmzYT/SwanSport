import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/documents/application/document_permissions.dart';
import 'package:swansport_app/features/documents/application/document_vault_controller.dart';
import 'package:swansport_app/features/documents/data/fixture_document_repository.dart';
import 'package:swansport_app/features/documents/domain/models/document_vault.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  test('repository exposes detail, versions, related, overview and storage',
      () async {
    final repository = FixtureDocumentRepository();
    final detail =
        await repository.detail(const SwanId('document_consent_can'));
    expect(detail, isA<AppSuccess<VaultDocument>>());
    expect(
      (await repository.versions(const SwanId('document_consent_can')))
          is AppSuccess,
      isTrue,
    );
    expect(
      (await repository.related(const SwanId('document_consent_can')))
          is AppSuccess,
      isTrue,
    );
    final overview = repository.overview(FixtureDocumentRepository.fixtures);
    expect(overview.total, 4);
    expect(repository.storage.usagePercentage, 42);
  });

  test('enterprise search and composable filters are deterministic', () {
    const queries = [
      'muvafakat',
      'can yılmaz',
      'u-16',
      '2025-2026',
      'mehmet yılmaz',
      'veli',
    ];
    for (final query in queries) {
      expect(
        FixtureDocumentRepository.fixtures
            .where(DocumentFilter(query: query).matches),
        isNotEmpty,
      );
    }
    const filter = DocumentFilter(
      query: 'can',
      category: DocumentCategory.consent,
      favoritesOnly: true,
      pinnedOnly: true,
    );
    expect(
      FixtureDocumentRepository.fixtures.where(filter.matches),
      hasLength(1),
    );
    expect(
      FixtureDocumentRepository.fixtures
          .where(const DocumentFilter(query: 'none').matches),
      isEmpty,
    );
  });

  test('controller searches, resets, filters and mutates requests', () async {
    final controller =
        DocumentVaultController(repository: FixtureDocumentRepository());
    await Future<void>.delayed(Duration.zero);
    controller.search('Efe');
    expect(controller.state.filtered.single.athlete, 'Efe Kaya');
    controller.selectCategory(DocumentCategory.consent);
    expect(controller.state.filtered, isEmpty);
    controller.resetSearch();
    expect(controller.state.filtered.single.category, DocumentCategory.consent);
    final count = controller.state.requests.length;
    await controller.createRequest(
      'Kimlik',
      'Can Yılmaz',
      DateTime(2026, 8, 1),
    );
    expect(controller.state.requests, hasLength(count + 1));
    final request = controller.state.requests.first;
    await controller.setRequestStatus(request, DocumentRequestStatus.approved);
    expect(
      controller.state.requests.first.status,
      DocumentRequestStatus.approved,
    );
  });

  test('permissions stay outside widgets', () {
    expect(
      DocumentPermissions.forRole(DocumentRole.clubAdmin).canDelete,
      isTrue,
    );
    expect(
      DocumentPermissions.forRole(DocumentRole.guardian).canDelete,
      isFalse,
    );
    expect(
      DocumentPermissions.forRole(DocumentRole.guardian).canManageRequests,
      isFalse,
    );
  });
}

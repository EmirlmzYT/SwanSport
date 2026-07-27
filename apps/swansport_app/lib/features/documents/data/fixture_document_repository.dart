import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

import '../domain/models/document_vault.dart';

enum DocumentFixtureScenario { normal, empty, offline, failure }

class FixtureDocumentRepository {
  FixtureDocumentRepository();

  final List<DocumentRequest> _requests = [
    DocumentRequest(
      id: const SwanId('request_medical_efe'),
      title: 'EK-1 Sağlık Raporu',
      athlete: 'Efe Kaya',
      status: DocumentRequestStatus.overdue,
      dueAt: DateTime(2026, 7, 20),
      issuedBy: 'Ahmet Koç',
    ),
    DocumentRequest(
      id: const SwanId('request_license_arda'),
      title: 'Lisans Yenileme',
      athlete: 'Arda Şen',
      status: DocumentRequestStatus.fulfilled,
      dueAt: DateTime(2026, 7, 30),
      issuedBy: 'Ahmet Koç',
    ),
  ];

  static final List<VaultDocument> fixtures = [
    VaultDocument(
      id: const SwanId('document_consent_can'),
      filename: 'Veli Muvafakat Belgesi.pdf',
      category: DocumentCategory.consent,
      status: DocumentStatus.active,
      owner: 'Can Yılmaz',
      uploader: 'Mehmet Yılmaz',
      athlete: 'Can Yılmaz',
      team: 'U-16 Erkek',
      season: '2025-2026',
      tags: const ['veli', 'onay', 'muvafakat'],
      createdAt: DateTime(2026, 7, 20),
      expiresAt: DateTime(2027, 7, 20),
      isFavorite: true,
      isPinned: true,
      versions: [
        DocumentVersion(
          number: 2,
          uploader: 'Mehmet Yılmaz',
          createdAt: DateTime(2026, 7, 20),
          summary: 'İmzalı güncel belge',
          isCurrent: true,
        ),
        DocumentVersion(
          number: 1,
          uploader: 'Ahmet Koç',
          createdAt: DateTime(2026, 7, 18),
          summary: 'İlk yükleme',
        ),
      ],
      related: const [
        RelatedDocument(
          documentId: SwanId('document_medical_efe'),
          relationship: 'Takım sağlık dosyası',
          label: 'Sağlık Raporu & EK-1',
        ),
      ],
    ),
    VaultDocument(
      id: const SwanId('document_medical_efe'),
      filename: 'Sağlık Raporu & EK-1.pdf',
      category: DocumentCategory.medical,
      status: DocumentStatus.expiringSoon,
      owner: 'Efe Kaya',
      uploader: 'Dr. Selin Ak',
      athlete: 'Efe Kaya',
      team: 'U-16 Erkek',
      season: '2025-2026',
      tags: const ['sağlık', 'ek-1', 'rapor'],
      createdAt: DateTime(2026, 6, 30),
      expiresAt: DateTime(2026, 7, 30),
      versions: [
        DocumentVersion(
          number: 1,
          uploader: 'Dr. Selin Ak',
          createdAt: DateTime(2026, 6, 30),
          summary: 'Sağlık birimi yüklemesi',
          isCurrent: true,
        ),
      ],
      related: const [
        RelatedDocument(
          documentId: SwanId('missing_efe_consent'),
          relationship: 'Zorunlu tamamlayıcı',
          label: 'Veli Muvafakatnamesi',
          isMissing: true,
        ),
      ],
    ),
    VaultDocument(
      id: const SwanId('document_license_arda'),
      filename: 'Sporcu Lisans Yenileme.pdf',
      category: DocumentCategory.license,
      status: DocumentStatus.pendingApproval,
      owner: 'Arda Şen',
      uploader: 'Ahmet Koç',
      athlete: 'Arda Şen',
      team: 'U-16 Erkek',
      season: '2025-2026',
      tags: const ['lisans', 'federasyon'],
      createdAt: DateTime(2026, 7, 15),
      versions: [
        DocumentVersion(
          number: 1,
          uploader: 'Ahmet Koç',
          createdAt: DateTime(2026, 7, 15),
          summary: 'Onaya gönderildi',
          isCurrent: true,
        ),
      ],
      related: const [],
    ),
    VaultDocument(
      id: const SwanId('document_archived_plan'),
      filename: '2024 Antrenman Planı.pdf',
      category: DocumentCategory.training,
      status: DocumentStatus.archived,
      owner: 'U-16 Erkek',
      uploader: 'Ahmet Koç',
      athlete: '',
      team: 'U-16 Erkek',
      season: '2024-2025',
      tags: const ['antrenman', 'plan'],
      createdAt: DateTime(2025, 5, 1),
      versions: const [],
      related: const [],
    ),
  ];

  Future<AppResult<List<VaultDocument>>> list({
    DocumentFixtureScenario scenario = DocumentFixtureScenario.normal,
  }) async {
    if (scenario == DocumentFixtureScenario.failure) {
      return const AppError(
        AppFailure(code: 'document_failure', message: 'Belgeler yüklenemedi.'),
      );
    }
    return AppSuccess(
      scenario == DocumentFixtureScenario.empty ? const [] : fixtures,
    );
  }

  Future<AppResult<VaultDocument>> detail(SwanId id) async {
    final matches = fixtures.where((item) => item.id.value == id.value);
    return matches.isEmpty
        ? const AppError(
            AppFailure(
              code: 'document_not_found',
              message: 'Belge bulunamadı.',
            ),
          )
        : AppSuccess(matches.single);
  }

  Future<AppResult<List<DocumentVersion>>> versions(SwanId id) async {
    final result = await detail(id);
    return switch (result) {
      AppSuccess<VaultDocument>(value: final value) =>
        AppSuccess(value.versions),
      AppError<VaultDocument>(failure: final failure) => AppError(failure),
    };
  }

  Future<AppResult<List<RelatedDocument>>> related(SwanId id) async {
    final result = await detail(id);
    return switch (result) {
      AppSuccess<VaultDocument>(value: final value) =>
        AppSuccess(value.related),
      AppError<VaultDocument>(failure: final failure) => AppError(failure),
    };
  }

  Future<List<DocumentRequest>> requests() async =>
      List.unmodifiable(_requests);

  Future<DocumentRequest> createRequest({
    required String title,
    required String athlete,
    required DateTime dueAt,
  }) async {
    final request = DocumentRequest(
      id: SwanId('request_${_requests.length + 1}'),
      title: title,
      athlete: athlete,
      status: DocumentRequestStatus.issued,
      dueAt: dueAt,
      issuedBy: 'Ahmet Koç',
    );
    _requests.add(request);
    return request;
  }

  Future<DocumentRequest?> updateRequest(
    SwanId id,
    DocumentRequestStatus status,
  ) async {
    final index = _requests.indexWhere((item) => item.id.value == id.value);
    if (index < 0) return null;
    _requests[index] = _requests[index].copyWith(status: status);
    return _requests[index];
  }

  VaultOverview overview(List<VaultDocument> documents) => VaultOverview(
        total: documents.length,
        active:
            documents.where((d) => d.status == DocumentStatus.active).length,
        expiringSoon: documents
            .where((d) => d.status == DocumentStatus.expiringSoon)
            .length,
        pendingApproval: documents
            .where((d) => d.status == DocumentStatus.pendingApproval)
            .length,
        archived:
            documents.where((d) => d.status == DocumentStatus.archived).length,
      );

  StorageOverview get storage =>
      const StorageOverview(usedGb: 4.2, totalGb: 10, health: 'Sağlıklı');
}

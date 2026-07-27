import '../domain/models/document_vault.dart';

class DocumentPermissions {
  const DocumentPermissions._();

  static DocumentPermissionSet forRole(DocumentRole role) => switch (role) {
        DocumentRole.superAdmin ||
        DocumentRole.clubAdmin =>
          const DocumentPermissionSet(
            canView: true,
            canUpload: true,
            canUpdate: true,
            canArchive: true,
            canDelete: true,
            canDownload: true,
            canManageRequests: true,
          ),
        DocumentRole.coach ||
        DocumentRole.medicalStaff =>
          const DocumentPermissionSet(
            canView: true,
            canUpload: true,
            canUpdate: true,
            canArchive: false,
            canDelete: false,
            canDownload: true,
            canManageRequests: true,
          ),
        DocumentRole.athlete ||
        DocumentRole.guardian =>
          const DocumentPermissionSet(
            canView: true,
            canUpload: true,
            canUpdate: false,
            canArchive: false,
            canDelete: false,
            canDownload: true,
            canManageRequests: false,
          ),
      };
}

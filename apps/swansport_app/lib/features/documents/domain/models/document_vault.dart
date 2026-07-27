import 'package:swansport_models/swansport_models.dart';

enum DocumentCategory {
  consent,
  medical,
  license,
  training,
  attendance,
  communication
}

enum DocumentStatus {
  active,
  expiringSoon,
  pendingApproval,
  archived,
  expired,
  unavailable
}

enum DocumentRole {
  superAdmin,
  clubAdmin,
  coach,
  medicalStaff,
  athlete,
  guardian
}

enum DocumentRequestStatus {
  issued,
  pending,
  fulfilled,
  approved,
  overdue,
  cancelled,
  rejected
}

class DocumentPermissionSet {
  const DocumentPermissionSet({
    required this.canView,
    required this.canUpload,
    required this.canUpdate,
    required this.canArchive,
    required this.canDelete,
    required this.canDownload,
    required this.canManageRequests,
  });
  final bool canView, canUpload, canUpdate, canArchive, canDelete, canDownload;
  final bool canManageRequests;
}

class DocumentVersion {
  const DocumentVersion({
    required this.number,
    required this.uploader,
    required this.createdAt,
    required this.summary,
    this.isCurrent = false,
  });
  final int number;
  final String uploader;
  final DateTime createdAt;
  final String summary;
  final bool isCurrent;
}

class RelatedDocument {
  const RelatedDocument({
    required this.documentId,
    required this.relationship,
    required this.label,
    this.isMissing = false,
  });
  final SwanId documentId;
  final String relationship;
  final String label;
  final bool isMissing;
}

class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.filename,
    required this.category,
    required this.status,
    required this.owner,
    required this.uploader,
    required this.athlete,
    required this.team,
    required this.season,
    required this.tags,
    required this.createdAt,
    required this.versions,
    required this.related,
    this.expiresAt,
    this.isFavorite = false,
    this.isPinned = false,
  });
  final SwanId id;
  final String filename, owner, uploader, athlete, team, season;
  final DocumentCategory category;
  final DocumentStatus status;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isFavorite, isPinned;
  final List<DocumentVersion> versions;
  final List<RelatedDocument> related;
}

class DocumentRequest {
  const DocumentRequest({
    required this.id,
    required this.title,
    required this.athlete,
    required this.status,
    required this.dueAt,
    required this.issuedBy,
  });
  final SwanId id;
  final String title, athlete, issuedBy;
  final DocumentRequestStatus status;
  final DateTime dueAt;

  DocumentRequest copyWith({DocumentRequestStatus? status}) => DocumentRequest(
        id: id,
        title: title,
        athlete: athlete,
        status: status ?? this.status,
        dueAt: dueAt,
        issuedBy: issuedBy,
      );
}

class VaultOverview {
  const VaultOverview({
    required this.total,
    required this.active,
    required this.expiringSoon,
    required this.pendingApproval,
    required this.archived,
  });
  final int total, active, expiringSoon, pendingApproval, archived;
}

class StorageOverview {
  const StorageOverview({
    required this.usedGb,
    required this.totalGb,
    required this.health,
  });
  final double usedGb, totalGb;
  final String health;
  int get usagePercentage => (usedGb / totalGb * 100).round();
}

class DocumentFilter {
  const DocumentFilter({
    this.query = '',
    this.category,
    this.athlete,
    this.team,
    this.season,
    this.status,
    this.uploader,
    this.favoritesOnly = false,
    this.pinnedOnly = false,
    this.from,
    this.to,
  });
  final String query;
  final DocumentCategory? category;
  final String? athlete, team, season, uploader;
  final DocumentStatus? status;
  final bool favoritesOnly, pinnedOnly;
  final DateTime? from, to;

  bool matches(VaultDocument document) {
    final q = query.trim().toLowerCase();
    final searchable = [
      document.filename,
      document.athlete,
      document.team,
      document.season,
      document.uploader,
      ...document.tags,
    ].join(' ').toLowerCase();
    return (q.isEmpty || searchable.contains(q)) &&
        (category == null || document.category == category) &&
        (athlete == null || document.athlete == athlete) &&
        (team == null || document.team == team) &&
        (season == null || document.season == season) &&
        (status == null || document.status == status) &&
        (uploader == null || document.uploader == uploader) &&
        (!favoritesOnly || document.isFavorite) &&
        (!pinnedOnly || document.isPinned) &&
        (from == null || !document.createdAt.isBefore(from!)) &&
        (to == null || !document.createdAt.isAfter(to!));
  }

  DocumentFilter copyWith({
    String? query,
    DocumentCategory? category,
    bool clearCategory = false,
    bool? favoritesOnly,
    bool? pinnedOnly,
  }) =>
      DocumentFilter(
        query: query ?? this.query,
        category: clearCategory ? null : category ?? this.category,
        athlete: athlete,
        team: team,
        season: season,
        status: status,
        uploader: uploader,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        pinnedOnly: pinnedOnly ?? this.pinnedOnly,
        from: from,
        to: to,
      );
}

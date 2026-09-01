import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';

enum AdminRole {
  superAdmin,
  clubAdmin,
  branchManager,
  coach,
  medicalStaff,
  guardian
}

enum UserStatus { active, invited, suspended, archived }

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.branch,
    required this.team,
    required this.permissions,
  });
  final SwanId id;
  final String name, email, branch, team;
  final AdminRole role;
  final UserStatus status;
  final Set<String> permissions;

  AdminUser copyWith({UserStatus? status}) => AdminUser(
        id: id,
        name: name,
        email: email,
        role: role,
        status: status ?? this.status,
        branch: branch,
        team: team,
        permissions: permissions,
      );
}

class AdminPermissionSet {
  const AdminPermissionSet({
    required this.canView,
    required this.canInvite,
    required this.canManageRoles,
    required this.canManageLifecycle,
    required this.canDelegate,
    required this.canViewAs,
    required this.canViewAudit,
  });
  final bool canView, canInvite, canManageRoles, canManageLifecycle;
  final bool canDelegate, canViewAs, canViewAudit;
}

class AdminAuditEntry {
  const AdminAuditEntry(this.actor, this.action, this.timestamp);
  final String actor, action;
  final DateTime timestamp;
}

class AdminDelegation {
  const AdminDelegation(this.from, this.to, this.expiresAt);
  final String from, to;
  final DateTime expiresAt;
}

class AdminOverview {
  const AdminOverview(this.capacity, this.active, this.invited, this.suspended);
  final int capacity, active, invited, suspended;
}

class AdminFilter {
  const AdminFilter({this.query = '', this.role, this.status, this.branch});
  final String query;
  final AdminRole? role;
  final UserStatus? status;
  final String? branch;
  bool matches(AdminUser user) {
    final q = query.trim();
    final haystack = '${user.name} ${user.email} ${user.team} ${user.branch}';
    return (q.isEmpty || trContains(haystack, q)) &&
        (role == null || role == user.role) &&
        (status == null || status == user.status) &&
        (branch == null || branch == user.branch);
  }

  AdminFilter copyWith({
    String? query,
    AdminRole? role,
    UserStatus? status,
    bool clearRole = false,
    bool clearStatus = false,
  }) =>
      AdminFilter(
        query: query ?? this.query,
        role: clearRole ? null : role ?? this.role,
        status: clearStatus ? null : status ?? this.status,
        branch: branch,
      );
}

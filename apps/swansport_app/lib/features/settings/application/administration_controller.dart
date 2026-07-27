import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_models/swansport_models.dart';

import '../domain/administration.dart';

class FixtureAdministrationRepository {
  final users = <AdminUser>[
    const AdminUser(
      id: SwanId('user_ahmet'),
      name: 'Ahmet Koç',
      email: 'ahmet@swansport.test',
      role: AdminRole.coach,
      status: UserStatus.active,
      branch: 'Basketbol',
      team: 'U-16 Erkek',
      permissions: {'athletes.view', 'attendance.manage'},
    ),
    const AdminUser(
      id: SwanId('user_selin'),
      name: 'Selin Yılmaz',
      email: 'selin@swansport.test',
      role: AdminRole.branchManager,
      status: UserStatus.active,
      branch: 'Basketbol',
      team: 'Tüm Takımlar',
      permissions: {'users.view', 'teams.manage'},
    ),
    const AdminUser(
      id: SwanId('user_mehmet'),
      name: 'Mehmet Yılmaz',
      email: 'mehmet@swansport.test',
      role: AdminRole.guardian,
      status: UserStatus.invited,
      branch: 'Basketbol',
      team: 'U-16 Erkek',
      permissions: {'athletes.self'},
    ),
    const AdminUser(
      id: SwanId('user_deniz'),
      name: 'Deniz Ak',
      email: 'deniz@swansport.test',
      role: AdminRole.medicalStaff,
      status: UserStatus.suspended,
      branch: 'Sağlık',
      team: 'Tüm Takımlar',
      permissions: {'medical.manage'},
    ),
  ];
  final audit = <AdminAuditEntry>[
    AdminAuditEntry(
      'Selin Yılmaz',
      'Ahmet Koç rolünü güncelledi',
      DateTime(2026, 7, 23, 14, 10),
    ),
  ];
  final delegations = <AdminDelegation>[
    AdminDelegation('Kulüp Yöneticisi', 'Selin Yılmaz', DateTime(2026, 7, 26)),
  ];
  Future<List<AdminUser>> list() async => List.unmodifiable(users);
  Future<AdminUser?> detail(SwanId id) async =>
      users.where((u) => u.id.value == id.value).firstOrNull;
  Future<void> invite(String name, String email, AdminRole role) async {
    users.add(
      AdminUser(
        id: SwanId('user_${users.length + 1}'),
        name: name,
        email: email,
        role: role,
        status: UserStatus.invited,
        branch: 'Basketbol',
        team: 'Atanmadı',
        permissions: const {},
      ),
    );
    audit.add(
      AdminAuditEntry(
        'Kulüp Yöneticisi',
        '$name davet edildi',
        DateTime(2026, 7, 23, 16),
      ),
    );
  }

  Future<void> setStatus(AdminUser user, UserStatus status) async {
    final index = users.indexWhere((u) => u.id.value == user.id.value);
    users[index] = user.copyWith(status: status);
  }
}

AdminPermissionSet permissionsFor(AdminRole role) => switch (role) {
      AdminRole.superAdmin || AdminRole.clubAdmin => const AdminPermissionSet(
          canView: true,
          canInvite: true,
          canManageRoles: true,
          canManageLifecycle: true,
          canDelegate: true,
          canViewAs: true,
          canViewAudit: true,
        ),
      AdminRole.branchManager => const AdminPermissionSet(
          canView: true,
          canInvite: true,
          canManageRoles: false,
          canManageLifecycle: true,
          canDelegate: false,
          canViewAs: true,
          canViewAudit: true,
        ),
      _ => const AdminPermissionSet(
          canView: false,
          canInvite: false,
          canManageRoles: false,
          canManageLifecycle: false,
          canDelegate: false,
          canViewAs: false,
          canViewAudit: false,
        ),
    };

class AdministrationState {
  const AdministrationState({
    this.loading = true,
    this.users = const [],
    this.filter = const AdminFilter(),
    required this.permissions,
    this.viewAs,
  });
  final bool loading;
  final List<AdminUser> users;
  final AdminFilter filter;
  final AdminPermissionSet permissions;
  final AdminUser? viewAs;
  List<AdminUser> get filtered => users.where(filter.matches).toList();
  AdminOverview get overview => AdminOverview(
        150,
        users.where((u) => u.status == UserStatus.active).length,
        users.where((u) => u.status == UserStatus.invited).length,
        users.where((u) => u.status == UserStatus.suspended).length,
      );
  AdministrationState copyWith({
    bool? loading,
    List<AdminUser>? users,
    AdminFilter? filter,
    AdminUser? viewAs,
    bool clearViewAs = false,
  }) =>
      AdministrationState(
        loading: loading ?? this.loading,
        users: users ?? this.users,
        filter: filter ?? this.filter,
        permissions: permissions,
        viewAs: clearViewAs ? null : viewAs ?? this.viewAs,
      );
}

final administrationRepositoryProvider =
    Provider((ref) => FixtureAdministrationRepository());
final administrationControllerProvider = StateNotifierProvider.autoDispose<
    AdministrationController, AdministrationState>(
  (ref) =>
      AdministrationController(ref.watch(administrationRepositoryProvider)),
);

class AdministrationController extends StateNotifier<AdministrationState> {
  AdministrationController(
    this.repository, {
    AdminRole role = AdminRole.clubAdmin,
  }) : super(AdministrationState(permissions: permissionsFor(role))) {
    load();
  }
  final FixtureAdministrationRepository repository;
  Future<void> load() async => state = state.copyWith(
        loading: false,
        users: state.permissions.canView ? await repository.list() : const [],
      );
  void search(String value) =>
      state = state.copyWith(filter: state.filter.copyWith(query: value));
  void role(AdminRole? value) => state = state.copyWith(
        filter: state.filter.copyWith(role: value, clearRole: value == null),
      );
  void status(UserStatus? value) => state = state.copyWith(
        filter:
            state.filter.copyWith(status: value, clearStatus: value == null),
      );
  void viewAs(AdminUser? user) =>
      state = state.copyWith(viewAs: user, clearViewAs: user == null);
  Future<void> invite(String name, String email, AdminRole role) async {
    if (!state.permissions.canInvite) return;
    await repository.invite(name, email, role);
    await load();
  }

  Future<void> lifecycle(AdminUser user, UserStatus status) async {
    if (!state.permissions.canManageLifecycle) return;
    await repository.setStatus(user, status);
    await load();
  }
}

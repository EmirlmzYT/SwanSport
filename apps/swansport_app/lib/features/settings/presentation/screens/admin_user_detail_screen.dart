import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/administration_controller.dart';
import '../../domain/administration.dart';
import '../routing/admin_user_detail_args.dart';

class AdminUserDetailScreen extends ConsumerWidget {
  const AdminUserDetailScreen({required this.args, super.key});
  final AdminUserDetailArgs? args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Geçersiz kullanıcı bağlantısı.')),
      );
    }
    final state = ref.watch(administrationControllerProvider);
    final users = state.users.where((u) => u.id.value == args!.userId.value);
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (users.isEmpty) {
      return const Scaffold(body: Center(child: Text('Kullanıcı bulunamadı.')));
    }
    final user = users.single;
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Ayrıntısı')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            user.name,
            key: const Key('admin-user-detail-name'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text(user.email),
          Text('Rol: ${user.role.name}'),
          Text('Durum: ${user.status.name}'),
          Text('Şube: ${user.branch} • Takım: ${user.team}'),
          const SizedBox(height: 20),
          const Text('İzinler', style: TextStyle(fontWeight: FontWeight.w900)),
          ...user.permissions.map(
            (p) => ListTile(leading: const Icon(Icons.check), title: Text(p)),
          ),
          if (state.permissions.canManageLifecycle)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => ref
                      .read(administrationControllerProvider.notifier)
                      .lifecycle(user, UserStatus.active),
                  child: const Text('Etkinleştir'),
                ),
                OutlinedButton(
                  onPressed: () => ref
                      .read(administrationControllerProvider.notifier)
                      .lifecycle(user, UserStatus.suspended),
                  child: const Text('Askıya Al'),
                ),
                OutlinedButton(
                  onPressed: () => ref
                      .read(administrationControllerProvider.notifier)
                      .lifecycle(user, UserStatus.archived),
                  child: const Text('Arşivle'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

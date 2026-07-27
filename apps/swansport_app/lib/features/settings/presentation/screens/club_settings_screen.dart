import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../application/administration_controller.dart';
import '../../domain/administration.dart';
import '../routing/admin_user_detail_args.dart';

class ClubSettingsScreen extends ConsumerWidget {
  const ClubSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(administrationControllerProvider);
    final controller = ref.read(administrationControllerProvider.notifier);

    if (!state.permissions.canView) {
      return const Scaffold(
        body: Center(
          child: Text('Yönetim merkezini görüntüleme yetkiniz yok.'),
        ),
      );
    }

    return Scaffold(
      appBar: SwanAppBar(
        clubName: 'Kadıköy SK',
        roleName: 'Kulüp Yöneticisi',
        actions: [
          if (state.permissions.canInvite)
            IconButton(
              key: const Key('admin-invite'),
              tooltip: 'Kullanıcı davet et',
              onPressed: () => _invite(context, controller),
              icon: const Icon(Icons.person_add),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                final overview =
                    _Overview(state: state, controller: controller);
                final directory =
                    _Directory(state: state, controller: controller);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                  children: [
                    const Text(
                      'KULÜP YAPILANDIRMASI & YÖNETİM MERKEZİ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                        fontSize: 11,
                        color: SwanColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Operasyonel Sistem Ayarları',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.viewAs case final user?)
                      Card(
                        color: SwanColors.warning.withValues(alpha: .12),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          leading: const Icon(
                            Icons.visibility,
                            color: SwanColors.warning,
                          ),
                          title: Text(
                            '${user.name} olarak görüntüleniyor • Salt Okunur',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () => controller.viewAs(null),
                            child: const Text(
                              'Yöneticiye Dön',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                    if (box.maxWidth >= 900)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: overview),
                          const SizedBox(width: 24),
                          Expanded(flex: 7, child: directory),
                        ],
                      )
                    else ...[
                      overview,
                      const SizedBox(height: 16),
                      directory,
                    ],
                  ],
                );
              },
            ),
    );
  }

  Future<void> _invite(
    BuildContext context,
    AdministrationController controller,
  ) async {
    final name = TextEditingController();
    final email = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Kullanıcı Davet Et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('invite-name'),
              controller: name,
              decoration: const InputDecoration(labelText: 'Ad Soyad'),
            ),
            TextField(
              key: const Key('invite-email'),
              controller: email,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Davet Et'),
          ),
        ],
      ),
    );

    if (ok == true && name.text.isNotEmpty && email.text.isNotEmpty) {
      await controller.invite(name.text, email.text, AdminRole.coach);
    }
    name.dispose();
    email.dispose();
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.state, required this.controller});

  final AdministrationState state;
  final AdministrationController controller;

  @override
  Widget build(BuildContext context) {
    final o = state.overview;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── GOVERNANCE & CAPACITY HERO ───────────────────────────────────
        Container(
          key: const Key('admin-overview'),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF063337), Color(0xFF008C95)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF008C95).withValues(alpha: 0.3),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ORGANIZATION & HEALTH: %98',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${o.active + o.invited + o.suspended} / ${o.capacity} Lisanslı Kullanıcı',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${o.capacity - o.active - o.invited - o.suspended} boş koltuk  •  3 Aktif Branş',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                children: [
                  _HeroStat(value: '${o.active}', label: '🟢 Aktif'),
                  _HeroStat(value: '${o.invited}', label: '🟡 Davet'),
                  _HeroStat(value: '${o.suspended}', label: '🔴 Askıda'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── CONFIGURATION VALIDATION CENTER ───────────────────────────────
        Card(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.health_and_safety_rounded,
                      color: SwanColors.success,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yapılandırma Doğrulama & Sağlık',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sistem yapılandırma sağlık skoru: %98. 0 Kritik Hata, 1 Uyarı.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : SwanColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── CONFIGURATION PROFILES & HISTORY LOG ─────────────────────────
        const Card(
          child: ExpansionTile(
            leading: Icon(
              Icons.dashboard_customize_rounded,
              color: SwanColors.primary,
            ),
            title: Text(
              'Şablon Profiller & Değişiklik Logu',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            subtitle: Text(
              'Basketbol/Futbol profilleri ve ayar geçmişi',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              ListTile(
                title: Text('🏀 Basketbol Akademisi Profili'),
                subtitle:
                    Text('90dk Antrenman, 4 Periyot Maç, EK-1 Sağlık Zorunlu'),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
              ListTile(
                title: Text('⚽ Futbol Akademisi Profili'),
                subtitle: Text('2 Devre Maç, Saha Seyahat Kontrol Listesi'),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
              ListTile(
                title: Text('📜 Antrenman Süresi: 60dk → 90dk'),
                subtitle: Text('Ahmet Koç • Bugün 14:20 • U-16 Lig Hazırlığı'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── ROLE & PERMISSION MANAGEMENT ──────────────────────────────────
        Card(
          child: ExpansionTile(
            leading:
                const Icon(Icons.shield_rounded, color: SwanColors.primary),
            title: const Text(
              'Rol & İzin Yönetimi (RBAC)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            children: AdminRole.values
                .map(
                  (r) => ListTile(
                    title: Text(r.name),
                    subtitle: Text(
                      '${FixtureAdministrationRepository().users.where((u) => u.role == r).length} kullanıcı atandı',
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        if (state.permissions.canDelegate)
          const Card(
            child: ListTile(
              leading: Icon(Icons.assignment_ind, color: SwanColors.primary),
              title: Text(
                'İdari Yetki Devri (Vekalet)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              subtitle: Text('S. Yılmaz • Şube Sorumlusu Vekili (3 gün kaldı)'),
            ),
          ),

        if (state.permissions.canViewAudit)
          Card(
            child: ExpansionTile(
              leading: const Icon(
                Icons.find_in_page_rounded,
                color: SwanColors.primary,
              ),
              title: const Text(
                'İdari Denetim Kaydı (Audit Log)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              children: controller.repository.audit
                  .map(
                    (e) => ListTile(
                      title: Text(e.action),
                      subtitle: Text(e.actor),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _Directory extends StatelessWidget {
  const _Directory({required this.state, required this.controller});

  final AdministrationState state;
  final AdministrationController controller;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(
            key: const Key('admin-search'),
            onChanged: controller.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Ad, e-posta, takım veya şube ara',
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tüm Roller'),
                  selected: state.filter.role == null,
                  onSelected: (_) => controller.role(null),
                ),
                ...AdminRole.values.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(r.name),
                      selected: state.filter.role == r,
                      onSelected: (_) => controller.role(r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Eşleşen kullanıcı bulunamadı.',
                key: Key('admin-empty'),
              ),
            ),
          ...state.filtered.map(
            (user) => Card(
              child: ListTile(
                key: Key('admin-user-${user.id.value}'),
                leading: CircleAvatar(child: Text(user.name.substring(0, 1))),
                title: Text(user.name),
                subtitle: Text(
                  '${user.email}\n${user.role.name} • ${user.status.name} • ${user.team}',
                ),
                isThreeLine: true,
                trailing: state.permissions.canViewAs
                    ? IconButton(
                        tooltip: 'Salt okunur görüntüle',
                        onPressed: () => controller.viewAs(user),
                        icon: const Icon(Icons.visibility),
                      )
                    : null,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/admin-user-detail',
                  arguments: AdminUserDetailArgs(user.id),
                ),
              ),
            ),
          ),
        ],
      );
}

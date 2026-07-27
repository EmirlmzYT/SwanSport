import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import '../../application/home_controller.dart';
import '../../domain/home_command_center.dart';

class HomeCommandCenterScreen extends ConsumerWidget {
  const HomeCommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeControllerProvider);
    final c = ref.read(homeControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwanColors.darkBackground : SwanColors.background;

    if (state.loading) {
      return const Scaffold(
        body: _HomeSkeleton(),
      );
    }
    if (state.error != null) {
      return Scaffold(
        body: Center(
          child: Semantics(
            liveRegion: true,
            child: Text(
              'Komuta merkezi yüklenemedi: ${state.error}',
              key: const Key('home-error'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text(
          'SwanSpor — Komuta Merkezi',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (MediaQuery.sizeOf(context).width >= 700)
            DropdownButton<String>(
              key: const Key('home-branch-selector'),
              value: state.filter.branch,
              underline: const SizedBox(),
              onChanged: (branch) {
                if (branch != null) c.changeBranch(branch);
              },
              items: const [
                DropdownMenuItem(
                  value: 'Kadıköy Şubesi',
                  child: Text('Kadıköy'),
                ),
                DropdownMenuItem(
                  value: 'Ataşehir Şubesi',
                  child: Text('Ataşehir'),
                ),
              ],
            )
          else
            PopupMenuButton<String>(
              key: const Key('home-branch-selector'),
              tooltip: 'Şube seç',
              icon: const Icon(Icons.business),
              onSelected: c.changeBranch,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'Kadıköy Şubesi',
                  child: Text('Kadıköy'),
                ),
                PopupMenuItem(
                  value: 'Ataşehir Şubesi',
                  child: Text('Ataşehir'),
                ),
              ],
            ),
          if (MediaQuery.sizeOf(context).width >= 700)
            DropdownButton<HomeRole>(
              key: const Key('home-role-switcher'),
              value: state.currentRole,
              underline: const SizedBox(),
              onChanged: (role) {
                if (role != null) c.changeRole(role);
              },
              items: HomeRole.values
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        _roleLabel(r),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            )
          else
            PopupMenuButton<HomeRole>(
              key: const Key('home-role-switcher'),
              tooltip: 'Rol seç',
              icon: const Icon(Icons.manage_accounts),
              onSelected: c.changeRole,
              itemBuilder: (_) => HomeRole.values
                  .map(
                    (role) => PopupMenuItem(
                      value: role,
                      child: Text(_roleLabel(role)),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            key: const Key('home-notifications'),
            icon: Badge(
              label: Text('${state.unreadNotificationCount}'),
              isLabelVisible: state.unreadNotificationCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Bildirim merkezi',
            onPressed: () => _showNotifications(context, state, c),
          ),
          if (MediaQuery.sizeOf(context).width >= 700)
            IconButton(
              key: const Key('home-profile'),
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Profil',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil menüsü')),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.apps_rounded),
            tooltip: '15-Modül Başlatıcı',
            onPressed: () => Navigator.pushNamed(context, '/hub'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final isDesktop = box.maxWidth >= 900;

          final headerGreeting = Container(
            key: const Key('home-command-header'),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF008C95),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'OPERASYONEL KOMUTA MERKEZİ (${_roleLabel(state.currentRole).toUpperCase()})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (box.maxWidth >= 600)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          state.filter.branch,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hoş Geldiniz, Ahmet Hocam 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugün ${state.agenda.length} aktif antrenman programınız ve ${state.tasks.where((t) => !t.isCompleted).length} onay bekleyen göreviniz bulunmaktadır.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (state.canViewClubKpis)
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _kpiPill(
                        context,
                        'Katılım',
                        '%${state.metrics.todayAttendanceRate}',
                        '/attendance',
                      ),
                      _kpiPill(
                        context,
                        'Aktif Antrenman',
                        '${state.metrics.activeSessionsCount}',
                        '/calendar',
                      ),
                      _kpiPill(
                        context,
                        'Onay Bekleyen',
                        '${state.metrics.pendingApprovalsCount}',
                        '/financial-management',
                      ),
                      _kpiPill(
                        context,
                        'Kritik Uyarım',
                        '${state.metrics.criticalAlertsCount}',
                        '/medical-center',
                        isAlert: true,
                      ),
                      _kpiPill(
                        context,
                        'Takım Hazır Olma',
                        '%${state.metrics.squadReadinessRate}',
                        '/performance-analytics',
                      ),
                    ],
                  ),
              ],
            ),
          );

          final searchBar = TextField(
            key: const Key('home-global-search'),
            onChanged: c.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText:
                  'Sporcu, antrenman, fatura, medikal rapor veya duyuru ara...',
            ),
          );

          final searchResults = state.filter.query.trim().isEmpty
              ? const SizedBox.shrink()
              : Card(
                  key: const Key('home-search-results'),
                  child: Column(
                    children: [
                      if (state.globalResults.isEmpty &&
                          state.filteredTasks.isEmpty &&
                          state.filteredAlerts.isEmpty)
                        const ListTile(
                          title: Text('Yetkili kapsamda sonuç bulunamadı.'),
                        ),
                      for (final result in state.globalResults)
                        ListTile(
                          leading: const Icon(Icons.search),
                          title: Text(result.title),
                          subtitle: Text(result.category),
                          onTap: () =>
                              Navigator.pushNamed(context, result.route),
                        ),
                    ],
                  ),
                );

          final agendaSection = Card(
            key: const Key('home-agenda-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Bugünün Programı & Ajanda',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/calendar'),
                        child: const Text('Tüm Takvim'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.agenda.isEmpty)
                    const ListTile(
                      title: Text('Bugün için ajanda kaydı bulunmuyor.'),
                    ),
                  for (final item in state.agenda)
                    ListTile(
                      key: Key('agenda-${item.id.value}'),
                      leading: CircleAvatar(
                        backgroundColor:
                            SwanColors.primary.withValues(alpha: 0.1),
                        child:
                            const Icon(Icons.event, color: SwanColors.primary),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${item.time.hour}:${item.time.minute.toString().padLeft(2, '0')} • ${item.facilityZone} • ${item.teamName}',
                      ),
                      onTap: () =>
                          Navigator.pushNamed(context, item.actionRoute),
                      trailing: box.maxWidth >= 600 &&
                              MediaQuery.textScalerOf(context).scale(1) < 1.5
                          ? const Icon(Icons.chevron_right)
                          : null,
                    ),
                ],
              ),
            ),
          );

          final tasksSection = Card(
            key: const Key('home-tasks-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Görevlerim & Onay Bekleyenler (${state.filteredTasks.where((t) => !t.isCompleted).length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.filteredTasks.isEmpty)
                    const ListTile(title: Text('Onay bekleyen görev yok.'))
                  else
                    for (final task in state.filteredTasks)
                      CheckboxListTile(
                        key: Key('task-${task.id.value}'),
                        value: task.isCompleted,
                        onChanged: (_) => c.completeTask(task.id),
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          'Kategori: ${task.category} • Öncelik: ${task.priority}',
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          onPressed: () =>
                              Navigator.pushNamed(context, task.actionRoute),
                        ),
                      ),
                ],
              ),
            ),
          );

          final alertsSection = Card(
            key: const Key('home-alerts-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kritik Uyarilar (${state.filteredAlerts.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.filteredAlerts.isEmpty)
                    const ListTile(
                      title: Text('Aktif kritik uyarı bulunmuyor.'),
                    )
                  else
                    for (final alert in state.filteredAlerts)
                      ListTile(
                        key: Key('alert-${alert.id.value}'),
                        leading: Icon(
                          alert.severity == HomeAlertSeverity.critical
                              ? Icons.error
                              : Icons.warning,
                          color: alert.severity == HomeAlertSeverity.critical
                              ? Colors.red
                              : Colors.amber,
                        ),
                        title: Text(
                          alert.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(alert.message),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () => c.dismissAlert(alert.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => Navigator.pushNamed(
                                context,
                                alert.actionRoute,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          );

          final launcherGrid = Card(
            key: const Key('home-fav-modules-grid'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FAVORİ & 15-MODÜL KISAYOLLARI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: SwanColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hızlı Modül Erişimi',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount:
                        isDesktop ? 3 : (box.maxWidth < 600 ? 1 : 2),
                    childAspectRatio:
                        isDesktop ? 2.5 : (box.maxWidth < 600 ? 3.2 : 2.2),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: const [
                      _FavItem(
                        icon: Icons.sports_soccer,
                        title: 'Sporcu Yönetimi',
                        route: '/athletes',
                      ),
                      _FavItem(
                        icon: Icons.fact_check,
                        title: 'Yoklama & Katılım',
                        route: '/attendance',
                      ),
                      _FavItem(
                        icon: Icons.calendar_month,
                        title: 'Takvim & Program',
                        route: '/calendar',
                      ),
                      _FavItem(
                        icon: Icons.campaign,
                        title: 'İletişim & Duyurular',
                        route: '/announcements',
                      ),
                      _FavItem(
                        icon: Icons.groups,
                        title: 'Takımlar & Şubeler',
                        route: '/teams',
                      ),
                      _FavItem(
                        icon: Icons.folder,
                        title: 'Evrak & Belgeler',
                        route: '/documents',
                      ),
                      _FavItem(
                        icon: Icons.settings,
                        title: 'Kulüp Ayarları',
                        route: '/settings',
                      ),
                      _FavItem(
                        icon: Icons.tune,
                        title: 'Konfigürasyon',
                        route: '/configuration',
                      ),
                      _FavItem(
                        icon: Icons.stadium,
                        title: 'Tesis Yönetimi',
                        route: '/facilities',
                      ),
                      _FavItem(
                        icon: Icons.medical_services,
                        title: 'Medikal Merkez',
                        route: '/medical-center',
                      ),
                      _FavItem(
                        icon: Icons.analytics,
                        title: 'Raporlama & BI',
                        route: '/reports',
                      ),
                      _FavItem(
                        icon: Icons.account_balance_wallet,
                        title: 'Finans Yönetimi',
                        route: '/financial-management',
                      ),
                      _FavItem(
                        icon: Icons.insights,
                        title: 'Performans Analizi',
                        route: '/performance-analytics',
                      ),
                      _FavItem(
                        icon: Icons.dashboard,
                        title: 'Koç Paneli',
                        route: '/dashboard',
                      ),
                      _FavItem(
                        icon: Icons.lock,
                        title: 'Giriş & Oturum',
                        route: '/',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          final activitySection = Card(
            key: const Key('home-activity-card'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Son Etkinlik & Denetim Akışı',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (state.visibleActivities.isEmpty)
                    const ListTile(
                      title: Text('Son etkinlik bulunmuyor.'),
                    ),
                  for (final act in state.visibleActivities)
                    ListTile(
                      key: Key('activity-${act.id.value}'),
                      leading:
                          const Icon(Icons.history, color: SwanColors.primary),
                      title: Text(act.title),
                      subtitle: Text(act.subtitle),
                      trailing: Text(
                        '${act.time.hour}:${act.time.minute.toString().padLeft(2, '0')}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          );

          final operationalSection = Card(
            key: const Key('home-operational-status'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operasyonel Durum',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _status(
                        'Uygun Sporcu',
                        state.operationalStatus.availableAthletes,
                      ),
                      _status(
                        'Kısıtlı Sporcu',
                        state.operationalStatus.restrictedAthletes,
                      ),
                      _status(
                        'Uygun Değil',
                        state.operationalStatus.unavailableAthletes,
                      ),
                      _status(
                        'Uygun Tesis',
                        state.operationalStatus.availableFacilities,
                      ),
                      _status(
                        'Antrenman',
                        state.operationalStatus.trainingSessions,
                      ),
                      _status('Müsabaka', state.operationalStatus.competitions),
                      const Chip(
                        avatar: Icon(Icons.cloud_outlined),
                        label: Text('Hava: demo veri yok'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          final personalizationSection = Card(
            key: const Key('home-widget-manager'),
            child: ExpansionTile(
              title: const Text('Widget Düzeni & Kişiselleştirme'),
              subtitle: const Text('Sıra, sabitleme, daraltma ve görünürlük'),
              children: [
                for (final widget in state.widgetPreferences)
                  ListTile(
                    key: Key('widget-pref-${widget.id}'),
                    title: Text(widget.id),
                    subtitle: Text(
                      '${widget.status.name} • sıra ${widget.order}${widget.collapsed ? ' • daraltıldı' : ''}${widget.hidden ? ' • gizli' : ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Widget işlemleri',
                      onSelected: (action) {
                        switch (action) {
                          case 'pin':
                            c.toggleWidgetPinned(widget.id);
                          case 'collapse':
                            c.toggleWidgetCollapsed(widget.id);
                          case 'move':
                            c.moveWidget(widget.id, 1);
                          case 'refresh':
                            c.refreshWidget(widget.id);
                          case 'hide':
                            c.hideWidget(widget.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'pin', child: Text('Sabitle')),
                        PopupMenuItem(
                          value: 'collapse',
                          child: Text('Daralt / Genişlet'),
                        ),
                        PopupMenuItem(
                          value: 'move',
                          child: Text('Aşağı Taşı'),
                        ),
                        PopupMenuItem(value: 'refresh', child: Text('Yenile')),
                        PopupMenuItem(value: 'hide', child: Text('Gizle')),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: c.restoreWidgets,
                  icon: const Icon(Icons.restore),
                  label: const Text('Gizlenenleri Geri Yükle'),
                ),
              ],
            ),
          );

          if (isDesktop) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                headerGreeting,
                const SizedBox(height: 16),
                searchBar,
                searchResults,
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          agendaSection,
                          const SizedBox(height: 16),
                          tasksSection,
                          const SizedBox(height: 16),
                          alertsSection,
                          const SizedBox(height: 16),
                          operationalSection,
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          launcherGrid,
                          const SizedBox(height: 16),
                          activitySection,
                          const SizedBox(height: 16),
                          personalizationSection,
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              headerGreeting,
              const SizedBox(height: 16),
              searchBar,
              searchResults,
              const SizedBox(height: 16),
              agendaSection,
              const SizedBox(height: 16),
              tasksSection,
              const SizedBox(height: 16),
              alertsSection,
              const SizedBox(height: 16),
              operationalSection,
              const SizedBox(height: 16),
              launcherGrid,
              const SizedBox(height: 16),
              activitySection,
              const SizedBox(height: 16),
              personalizationSection,
            ],
          );
        },
      ),
    );
  }

  Widget _status(String label, int value) => Chip(
        label: Text('$label: $value'),
      );

  Future<void> _showNotifications(
    BuildContext context,
    HomeCommandCenterState state,
    HomeController controller,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            key: const Key('home-notification-center'),
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Bildirim Merkezi',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              for (final item in state.notifications)
                ListTile(
                  leading: Icon(
                    item.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                  ),
                  title: Text(item.title),
                  subtitle: Text('${item.kind.name} • ${item.priority}'),
                  onTap: () {
                    controller.markNotificationRead(item.id);
                    Navigator.pop(context);
                    Navigator.pushNamed(context, item.route);
                  },
                  trailing: IconButton(
                    tooltip: item.isPinned ? 'Sabitlemeyi kaldır' : 'Sabitle',
                    onPressed: () =>
                        controller.toggleNotificationPinned(item.id),
                    icon: Icon(
                      item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _kpiPill(
    BuildContext context,
    String label,
    String value,
    String route, {
    bool isAlert = false,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isAlert
              ? Colors.red.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: isAlert ? Border.all(color: Colors.redAccent) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: isAlert ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(HomeRole r) {
    switch (r) {
      case HomeRole.clubOwner:
        return 'Kulüp Başkanı';
      case HomeRole.administrator:
        return 'Kulüp Yöneticisi';
      case HomeRole.headCoach:
        return 'Baş Antrenör';
      case HomeRole.coach:
        return 'Antrenör';
      case HomeRole.scCoach:
        return 'Atletik Performans Koçu';
      case HomeRole.medicalStaff:
        return 'Sağlık / Medikal Ekip';
      case HomeRole.financialManager:
        return 'Finans Yöneticisi';
      case HomeRole.athlete:
        return 'Sporcu';
      case HomeRole.parent:
        return 'Veli / Ebeveyn';
      case HomeRole.auditor:
        return 'Denetçi / İzleyici';
    }
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        key: const Key('home-loading-skeleton'),
        padding: const EdgeInsets.all(20),
        children: [
          for (var index = 0; index < 5; index++)
            Container(
              height: index == 0 ? 150 : 90,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      );
}

class _FavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;

  const _FavItem({
    required this.icon,
    required this.title,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: SwanColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: SwanColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

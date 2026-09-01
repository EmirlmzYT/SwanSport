import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_models/swansport_models.dart';
import '../domain/home_command_center.dart';

class HomeCommandCenterState {
  final HomeRole currentRole;
  final HomeFilter filter;
  final HomeKpiMetrics metrics;
  final List<HomeAgendaItem> agenda;
  final List<HomeTaskItem> tasks;
  final List<HomeAlertItem> alerts;
  final List<HomeActivityItem> activities;
  final List<HomeNotificationItem> notifications;
  final List<HomeWidgetPreference> widgetPreferences;
  final HomeOperationalStatus operationalStatus;
  final List<HomeGlobalSearchResult> searchIndex;
  final bool loading;
  final String? error;

  const HomeCommandCenterState({
    required this.currentRole,
    required this.filter,
    required this.metrics,
    required this.agenda,
    required this.tasks,
    required this.alerts,
    required this.activities,
    required this.notifications,
    required this.widgetPreferences,
    required this.operationalStatus,
    required this.searchIndex,
    this.loading = false,
    this.error,
  });

  List<HomeTaskItem> get filteredTasks {
    final scoped = tasks.where((task) {
      if (task.category == 'Finans') {
        return currentRole == HomeRole.financialManager ||
            currentRole == HomeRole.clubOwner ||
            currentRole == HomeRole.administrator;
      }
      if (task.category == 'Medikal') {
        return currentRole == HomeRole.medicalStaff ||
            currentRole == HomeRole.clubOwner ||
            currentRole == HomeRole.administrator;
      }
      return true;
    });
    final ordered = scoped.toList()
      ..sort((a, b) {
        final roleCategory = switch (currentRole) {
          HomeRole.financialManager => 'Finans',
          HomeRole.medicalStaff => 'Medikal',
          _ => 'Koç Onayı',
        };
        final aRole = a.category == roleCategory ? 0 : 1;
        final bRole = b.category == roleCategory ? 0 : 1;
        if (aRole != bRole) return aRole.compareTo(bRole);
        const priority = {'Kritik': 0, 'Yüksek': 1, 'Orta': 2};
        return (priority[a.priority] ?? 9).compareTo(priority[b.priority] ?? 9);
      });
    if (filter.query.isEmpty) return ordered;
    final q = filter.query.toLowerCase();
    return ordered
        .where(
          (t) =>
              trContains(t.title, q) ||
              trContains(t.category, q),
        )
        .toList();
  }

  List<HomeGlobalSearchResult> get globalResults {
    final q = filter.query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return searchIndex.where((result) {
      if (result.category == 'Ödeme' &&
          currentRole != HomeRole.financialManager &&
          currentRole != HomeRole.clubOwner &&
          currentRole != HomeRole.administrator) {
        return false;
      }
      if (result.category == 'Medikal Clearance' &&
          currentRole != HomeRole.medicalStaff &&
          currentRole != HomeRole.clubOwner &&
          currentRole != HomeRole.administrator) {
        return false;
      }
      return trContains(result.title, q) ||
          trContains(result.category, q);
    }).toList();
  }

  List<HomeWidgetPreference> get visibleWidgets {
    final result = widgetPreferences.where((item) => !item.hidden).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return a.order.compareTo(b.order);
      });
    return result;
  }

  int get unreadNotificationCount =>
      notifications.where((item) => !item.isRead).length;

  List<HomeAlertItem> get filteredAlerts {
    final scoped = alerts.where((alert) {
      if (currentRole == HomeRole.athlete || currentRole == HomeRole.parent) {
        return alert.message.contains('Arda Yılmaz');
      }
      return true;
    });
    if (filter.query.isEmpty) return scoped.toList();
    final q = filter.query.toLowerCase();
    return scoped
        .where(
          (a) =>
              trContains(a.title, q) ||
              trContains(a.message, q),
        )
        .toList();
  }

  List<HomeActivityItem> get visibleActivities => activities.where((item) {
        if (item.iconType == 'payment') {
          return currentRole == HomeRole.financialManager ||
              currentRole == HomeRole.clubOwner ||
              currentRole == HomeRole.administrator ||
              currentRole == HomeRole.auditor;
        }
        return true;
      }).toList();

  bool get canViewClubKpis =>
      currentRole != HomeRole.athlete && currentRole != HomeRole.parent;

  HomeCommandCenterState copyWith({
    HomeRole? currentRole,
    HomeFilter? filter,
    HomeKpiMetrics? metrics,
    List<HomeAgendaItem>? agenda,
    List<HomeTaskItem>? tasks,
    List<HomeAlertItem>? alerts,
    List<HomeActivityItem>? activities,
    List<HomeNotificationItem>? notifications,
    List<HomeWidgetPreference>? widgetPreferences,
    HomeOperationalStatus? operationalStatus,
    List<HomeGlobalSearchResult>? searchIndex,
    bool? loading,
    String? error,
  }) {
    return HomeCommandCenterState(
      currentRole: currentRole ?? this.currentRole,
      filter: filter ?? this.filter,
      metrics: metrics ?? this.metrics,
      agenda: agenda ?? this.agenda,
      tasks: tasks ?? this.tasks,
      alerts: alerts ?? this.alerts,
      activities: activities ?? this.activities,
      notifications: notifications ?? this.notifications,
      widgetPreferences: widgetPreferences ?? this.widgetPreferences,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      searchIndex: searchIndex ?? this.searchIndex,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class HomeController extends StateNotifier<HomeCommandCenterState> {
  final FixtureHomeRepository repo;

  HomeController(this.repo)
      : super(
          HomeCommandCenterState(
            currentRole: HomeRole.headCoach,
            filter: const HomeFilter(),
            metrics: repo.metrics,
            agenda: repo.agenda,
            tasks: repo.tasks,
            alerts: repo.alerts,
            activities: repo.activities,
            notifications: repo.notifications,
            widgetPreferences: repo.widgetPreferences,
            operationalStatus: repo.operationalStatus,
            searchIndex: repo.searchIndex,
          ),
        );

  void changeRole(HomeRole role) {
    state = state.copyWith(currentRole: role);
  }

  void changeBranch(String branch) {
    state = state.copyWith(filter: state.filter.copyWith(branch: branch));
  }

  void search(String query) {
    state = state.copyWith(filter: state.filter.copyWith(query: query));
  }

  void completeTask(SwanId taskId) {
    if (state.currentRole == HomeRole.athlete ||
        state.currentRole == HomeRole.parent ||
        state.currentRole == HomeRole.auditor) {
      return;
    }
    final updated = state.tasks
        .map((t) => t.id == taskId ? t.copyWith(isCompleted: true) : t)
        .toList();
    state = state.copyWith(tasks: updated);
  }

  void dismissAlert(SwanId alertId) {
    if (state.currentRole == HomeRole.athlete ||
        state.currentRole == HomeRole.parent ||
        state.currentRole == HomeRole.auditor) {
      return;
    }
    final updated = state.alerts.where((a) => a.id != alertId).toList();
    state = state.copyWith(alerts: updated);
  }

  void markNotificationRead(SwanId id) {
    state = state.copyWith(
      notifications: [
        for (final item in state.notifications)
          if (item.id == id) item.copyWith(isRead: true) else item,
      ],
    );
  }

  void toggleNotificationPinned(SwanId id) {
    state = state.copyWith(
      notifications: [
        for (final item in state.notifications)
          if (item.id == id) item.copyWith(isPinned: !item.isPinned) else item,
      ],
    );
  }

  void toggleWidgetCollapsed(String id) => _updateWidget(
        id,
        (item) => item.copyWith(collapsed: !item.collapsed),
      );

  void toggleWidgetPinned(String id) => _updateWidget(
        id,
        (item) => item.copyWith(pinned: !item.pinned),
      );

  void hideWidget(String id) =>
      _updateWidget(id, (item) => item.copyWith(hidden: true));

  void restoreWidgets() {
    state = state.copyWith(
      widgetPreferences: [
        for (final item in state.widgetPreferences)
          item.copyWith(hidden: false),
      ],
    );
  }

  void moveWidget(String id, int delta) => _updateWidget(
        id,
        (item) => item.copyWith(order: (item.order + delta).clamp(0, 99)),
      );

  void refreshWidget(String id) {
    _updateWidget(id, (item) => item.copyWith(status: HomeWidgetStatus.ready));
  }

  void _updateWidget(
    String id,
    HomeWidgetPreference Function(HomeWidgetPreference) update,
  ) {
    state = state.copyWith(
      widgetPreferences: [
        for (final item in state.widgetPreferences)
          if (item.id == id) update(item) else item,
      ],
    );
  }
}

final homeRepositoryProvider = Provider<FixtureHomeRepository>((ref) {
  return FixtureHomeRepository();
});

final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeCommandCenterState>((ref) {
  final repo = ref.watch(homeRepositoryProvider);
  return HomeController(repo);
});

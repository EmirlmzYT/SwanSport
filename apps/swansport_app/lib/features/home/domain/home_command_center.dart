import 'package:swansport_models/swansport_models.dart';

enum HomeRole {
  clubOwner,
  administrator,
  headCoach,
  coach,
  scCoach,
  medicalStaff,
  financialManager,
  athlete,
  parent,
  auditor,
}

enum HomeAlertSeverity {
  critical,
  warning,
  information,
}

enum HomeAgendaStatus {
  upcoming,
  inProgress,
  completed,
  cancelled,
}

enum HomeNotificationKind { assignment, approval, mention, system }

enum HomeWidgetStatus {
  ready,
  loading,
  empty,
  offline,
  permissionDenied,
  error
}

class HomeNotificationItem {
  final SwanId id;
  final String title;
  final HomeNotificationKind kind;
  final bool isRead;
  final bool isPinned;
  final String priority;
  final String route;

  const HomeNotificationItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.isRead,
    required this.isPinned,
    required this.priority,
    required this.route,
  });

  HomeNotificationItem copyWith({bool? isRead, bool? isPinned}) =>
      HomeNotificationItem(
        id: id,
        title: title,
        kind: kind,
        isRead: isRead ?? this.isRead,
        isPinned: isPinned ?? this.isPinned,
        priority: priority,
        route: route,
      );
}

class HomeWidgetPreference {
  final String id;
  final int order;
  final bool pinned;
  final bool collapsed;
  final bool hidden;
  final HomeWidgetStatus status;

  const HomeWidgetPreference({
    required this.id,
    required this.order,
    this.pinned = false,
    this.collapsed = false,
    this.hidden = false,
    this.status = HomeWidgetStatus.ready,
  });

  HomeWidgetPreference copyWith({
    int? order,
    bool? pinned,
    bool? collapsed,
    bool? hidden,
    HomeWidgetStatus? status,
  }) =>
      HomeWidgetPreference(
        id: id,
        order: order ?? this.order,
        pinned: pinned ?? this.pinned,
        collapsed: collapsed ?? this.collapsed,
        hidden: hidden ?? this.hidden,
        status: status ?? this.status,
      );
}

class HomeOperationalStatus {
  final int availableAthletes;
  final int restrictedAthletes;
  final int unavailableAthletes;
  final int availableFacilities;
  final int trainingSessions;
  final int competitions;

  const HomeOperationalStatus({
    required this.availableAthletes,
    required this.restrictedAthletes,
    required this.unavailableAthletes,
    required this.availableFacilities,
    required this.trainingSessions,
    required this.competitions,
  });
}

class HomeGlobalSearchResult {
  final String title;
  final String category;
  final String route;

  const HomeGlobalSearchResult({
    required this.title,
    required this.category,
    required this.route,
  });
}

class HomeKpiMetrics {
  final int todayAttendanceRate;
  final int activeSessionsCount;
  final int pendingApprovalsCount;
  final int criticalAlertsCount;
  final int squadReadinessRate;

  const HomeKpiMetrics({
    required this.todayAttendanceRate,
    required this.activeSessionsCount,
    required this.pendingApprovalsCount,
    required this.criticalAlertsCount,
    required this.squadReadinessRate,
  });
}

class HomeAgendaItem {
  final SwanId id;
  final String title;
  final DateTime time;
  final String facilityZone;
  final String teamName;
  final HomeAgendaStatus status;
  final String actionRoute;

  const HomeAgendaItem({
    required this.id,
    required this.title,
    required this.time,
    required this.facilityZone,
    required this.teamName,
    required this.status,
    required this.actionRoute,
  });
}

class HomeTaskItem {
  final SwanId id;
  final String title;
  final String category;
  final DateTime dueDate;
  final String priority;
  final String actionRoute;
  final bool isCompleted;

  const HomeTaskItem({
    required this.id,
    required this.title,
    required this.category,
    required this.dueDate,
    required this.priority,
    required this.actionRoute,
    this.isCompleted = false,
  });

  HomeTaskItem copyWith({bool? isCompleted}) {
    return HomeTaskItem(
      id: id,
      title: title,
      category: category,
      dueDate: dueDate,
      priority: priority,
      actionRoute: actionRoute,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class HomeAlertItem {
  final SwanId id;
  final String title;
  final String message;
  final HomeAlertSeverity severity;
  final String actionRoute;

  const HomeAlertItem({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.actionRoute,
  });
}

class HomeActivityItem {
  final SwanId id;
  final String title;
  final String subtitle;
  final DateTime time;
  final String iconType;

  const HomeActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.iconType,
  });
}

class HomeFilter {
  final String query;
  final String branch;

  const HomeFilter({
    this.query = '',
    this.branch = 'Kadıköy Şubesi',
  });

  HomeFilter copyWith({String? query, String? branch}) {
    return HomeFilter(
      query: query ?? this.query,
      branch: branch ?? this.branch,
    );
  }
}

class FixtureHomeRepository {
  final HomeKpiMetrics metrics = const HomeKpiMetrics(
    todayAttendanceRate: 94,
    activeSessionsCount: 6,
    pendingApprovalsCount: 4,
    criticalAlertsCount: 2,
    squadReadinessRate: 92,
  );

  final List<HomeAgendaItem> _agenda = [
    HomeAgendaItem(
      id: const SwanId('agenda_1'),
      title: 'U18 Futbol Takımı Saha Antrenmanı',
      time: DateTime(2026, 7, 24, 16, 30),
      facilityZone: 'Ana Saha - Saha A',
      teamName: 'U18 Futbol',
      status: HomeAgendaStatus.upcoming,
      actionRoute: '/attendance',
    ),
    HomeAgendaItem(
      id: const SwanId('agenda_2'),
      title: 'A Takım Fiziksel Dayanıklılık Testi',
      time: DateTime(2026, 7, 24, 18, 00),
      facilityZone: 'Kondisyon Salonu 1',
      teamName: 'A Takım',
      status: HomeAgendaStatus.upcoming,
      actionRoute: '/performance-analytics',
    ),
    HomeAgendaItem(
      id: const SwanId('agenda_3'),
      title: 'Haftalık Sağlık & Sakatlık Kurulu',
      time: DateTime(2026, 7, 24, 19, 30),
      facilityZone: 'Medikal Toplantı Odası',
      teamName: 'Tüm Şubeler',
      status: HomeAgendaStatus.upcoming,
      actionRoute: '/medical-center',
    ),
  ];

  final List<HomeTaskItem> _tasks = [
    HomeTaskItem(
      id: const SwanId('task_1'),
      title: 'U18 Dünkü Maç Performans Değerlendirmesi',
      category: 'Koç Onayı',
      dueDate: DateTime(2026, 7, 24),
      priority: 'Yüksek',
      actionRoute: '/performance-analytics',
    ),
    HomeTaskItem(
      id: const SwanId('task_2'),
      title: 'Ece Sönmez Dönüş Protokolü Medikal Onayı',
      category: 'Medikal',
      dueDate: DateTime(2026, 7, 24),
      priority: 'Kritik',
      actionRoute: '/medical-center',
    ),
    HomeTaskItem(
      id: const SwanId('task_3'),
      title: 'Temmuz Ayı Saha Kiralama Gider Onayı (\$4,500 TL)',
      category: 'Finans',
      dueDate: DateTime(2026, 7, 25),
      priority: 'Orta',
      actionRoute: '/financial-management',
    ),
  ];

  final List<HomeAlertItem> _alerts = [
    const HomeAlertItem(
      id: SwanId('alert_1'),
      title: 'Medikal Kısıtlama Uyarısı',
      message:
          'Ece Sönmez antrenman kısıtlamasında. Doktordan henüz onay alınmadı.',
      severity: HomeAlertSeverity.critical,
      actionRoute: '/medical-center',
    ),
    const HomeAlertItem(
      id: SwanId('alert_2'),
      title: 'Aşırı Yüklenme Risk Uyarısı',
      message: 'Arda Yılmaz 7 günlük RPE yükleme oranı %18 arttı.',
      severity: HomeAlertSeverity.warning,
      actionRoute: '/performance-analytics',
    ),
  ];

  final List<HomeActivityItem> _activities = [
    HomeActivityItem(
      id: const SwanId('act_1'),
      title: '2.500 TL Ödeme Kaydedildi',
      subtitle: 'Mehmet Yılmaz • INV-2026-001',
      time: DateTime(2026, 7, 24, 14, 20),
      iconType: 'payment',
    ),
    HomeActivityItem(
      id: const SwanId('act_2'),
      title: 'Yeni Sporcu Lisansı Yüklendi',
      subtitle: 'Caner Erkin • TFF Lisans Belgesi',
      time: DateTime(2026, 7, 24, 12, 10),
      iconType: 'document',
    ),
  ];

  final List<HomeNotificationItem> _notifications = const [
    HomeNotificationItem(
      id: SwanId('notification_1'),
      title: 'U18 değerlendirmesi size atandı',
      kind: HomeNotificationKind.assignment,
      isRead: false,
      isPinned: true,
      priority: 'Yüksek',
      route: '/performance-analytics',
    ),
    HomeNotificationItem(
      id: SwanId('notification_2'),
      title: 'Tesis rezervasyonu onay bekliyor',
      kind: HomeNotificationKind.approval,
      isRead: false,
      isPinned: false,
      priority: 'Orta',
      route: '/facilities',
    ),
  ];

  final List<HomeWidgetPreference> _widgetPreferences = const [
    HomeWidgetPreference(id: 'agenda', order: 0, pinned: true),
    HomeWidgetPreference(id: 'tasks', order: 1),
    HomeWidgetPreference(id: 'alerts', order: 2, pinned: true),
    HomeWidgetPreference(id: 'operations', order: 3),
    HomeWidgetPreference(id: 'favorites', order: 4),
    HomeWidgetPreference(id: 'activity', order: 5),
  ];

  final HomeOperationalStatus operationalStatus = const HomeOperationalStatus(
    availableAthletes: 386,
    restrictedAthletes: 21,
    unavailableAthletes: 13,
    availableFacilities: 8,
    trainingSessions: 6,
    competitions: 2,
  );

  final List<HomeGlobalSearchResult> _searchIndex = const [
    HomeGlobalSearchResult(
      title: 'Arda Yılmaz',
      category: 'Sporcu',
      route: '/athletes',
    ),
    HomeGlobalSearchResult(
      title: 'U18 Elite',
      category: 'Takım',
      route: '/teams',
    ),
    HomeGlobalSearchResult(
      title: 'Kadıköy Ana Saha',
      category: 'Tesis',
      route: '/facilities',
    ),
    HomeGlobalSearchResult(
      title: 'Temmuz Performans Raporu',
      category: 'Rapor',
      route: '/reports',
    ),
    HomeGlobalSearchResult(
      title: 'Operasyonel medikal uygunluk',
      category: 'Medikal Clearance',
      route: '/medical-center',
    ),
    HomeGlobalSearchResult(
      title: 'Aidat ödeme durumu',
      category: 'Ödeme',
      route: '/financial-management',
    ),
  ];

  List<HomeAgendaItem> get agenda => List.unmodifiable(_agenda);
  List<HomeTaskItem> get tasks => List.unmodifiable(_tasks);
  List<HomeAlertItem> get alerts => List.unmodifiable(_alerts);
  List<HomeActivityItem> get activities => List.unmodifiable(_activities);
  List<HomeNotificationItem> get notifications =>
      List.unmodifiable(_notifications);
  List<HomeWidgetPreference> get widgetPreferences =>
      List.unmodifiable(_widgetPreferences);
  List<HomeGlobalSearchResult> get searchIndex =>
      List.unmodifiable(_searchIndex);
}

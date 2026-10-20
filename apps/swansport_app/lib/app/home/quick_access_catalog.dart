import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../features/demo/demo_role.dart';
import 'quick_access_preferences.dart';

class HomeShortcut {
  const HomeShortcut(
    this.id,
    this.label,
    this.icon,
    this.route, {
    this.flag,
    this.audience = 'all',
  });

  final String id, label, route, audience;
  final IconData icon;
  final String? flag;
}

const homeShortcutCatalog = <HomeShortcut>[
  HomeShortcut(
    'my_training',
    'Programım',
    Icons.sports_outlined,
    '/antrenmanlarim',
    audience: 'athlete',
    flag: FeatureFlags.sportTrainingSessions,
  ),
  HomeShortcut(
    'attendance',
    'Yoklama Al',
    Icons.fact_check_outlined,
    '/attendance',
    audience: 'staff',
  ),
  HomeShortcut(
    'training',
    'Antrenman',
    Icons.sports_outlined,
    '/antrenman-oturumu',
    audience: 'staff',
    flag: FeatureFlags.sportTrainingSessions,
  ),
  HomeShortcut(
    'roster',
    'Kadrom',
    Icons.groups_outlined,
    '/athletes',
    audience: 'staff',
  ),
  HomeShortcut(
    'calendar',
    'Takvim',
    Icons.calendar_month_outlined,
    '/calendar',
  ),
  HomeShortcut(
    'club',
    'Kulüp Yönetimi',
    Icons.space_dashboard_outlined,
    '/kulup-yonetim',
    audience: 'staff',
  ),
  HomeShortcut(
    'applications',
    'Başvurular',
    Icons.person_add_alt_outlined,
    '/basvurular',
    audience: 'admin',
  ),
  HomeShortcut(
    'finance',
    'Mali İşler',
    Icons.account_balance_wallet_outlined,
    '/mali-isler',
    audience: 'finance',
  ),
  HomeShortcut(
    'expenses',
    'Gider Ekle',
    Icons.receipt_long_outlined,
    '/gider-ekle',
    audience: 'finance',
  ),
  HomeShortcut(
    'dues_admin',
    'Aidat Yönetimi',
    Icons.payments_outlined,
    '/finans',
    audience: 'finance',
  ),
  HomeShortcut(
    'parent',
    'Çocuğum',
    Icons.family_restroom_outlined,
    '/veli-izinleri',
    audience: 'parent',
    flag: FeatureFlags.parentHub,
  ),
  HomeShortcut(
    'development',
    'Gelişimim',
    Icons.insights_outlined,
    '/gelisim-raporu',
    audience: 'athlete',
    flag: FeatureFlags.developmentReport,
  ),
  HomeShortcut(
    'dashboard',
    'Panelim',
    Icons.dashboard_outlined,
    '/dashboard',
    audience: 'athlete',
  ),
  HomeShortcut(
    'referee',
    'Görevlerim',
    Icons.sports_rounded,
    '/hakem/gorevler',
    audience: 'referee',
    flag: FeatureFlags.refereeCockpit,
  ),
  HomeShortcut(
    'approvals',
    'Onay Paneli',
    Icons.admin_panel_settings_outlined,
    '/onay-paneli',
    audience: 'platform',
  ),
  HomeShortcut('dues', 'Aidatlarım', Icons.payments_outlined, '/aidatlarim'),
  HomeShortcut('venues', 'Sahalar', Icons.stadium_outlined, '/kortlar'),
  HomeShortcut(
    'partner',
    'Partner Bul',
    Icons.handshake_outlined,
    '/partner-ara',
  ),
  HomeShortcut('clubs', 'Kulüpler', Icons.shield_outlined, '/kulupler'),
];

/// Visibility uses SwanAccess and the existing mobile route projection.
List<HomeShortcut> availableHomeShortcuts(
  SwanAccess access,
  Set<String> flags, {
  Set<String>? allowedRoutes,
}) {
  if (!access.hasAccount) return const [];
  return homeShortcutCatalog.where((item) {
    final audienceAllowed = switch (item.audience) {
      'staff' => access.isClubStaff,
      'admin' => access.isClubAdmin,
      'finance' => access.isClubAdmin || access.isAccountant,
      'parent' => access.isParent,
      'athlete' => access.isVerifiedAthlete || access.clubRole == 'athlete',
      'referee' => access.isReferee,
      'platform' => access.isPlatformAdmin,
      _ => true,
    };
    // Finance, guardian and referee routes have their own SwanAccess gates;
    // legacy demo route sets do not include these newer role axes.
    final projected = const {'finance', 'parent', 'referee', 'athlete'}
            .contains(item.audience) ||
        demoAllows(allowedRoutes, item.route);
    return audienceAllowed &&
        projected &&
        (item.flag == null || flags.contains(item.flag));
  }).toList();
}

List<HomeShortcut> defaultHomeShortcuts(
  SwanAccess access,
  List<HomeShortcut> available,
) {
  final priority = <String>[
    if (access.isPlatformAdmin) 'approvals',
    if (access.isReferee) 'referee',
    if (access.isClubAdmin) ...['club', 'applications', 'finance'],
    if (access.isClubStaff) ...['attendance', 'training', 'roster'],
    if (access.isParent) 'parent',
    if (access.isAccountant) ...['finance', 'expenses', 'dues_admin'],
    if (access.isVerifiedAthlete || access.clubRole == 'athlete') ...[
      'my_training',
      'development',
      'dashboard',
    ],
    'calendar',
    'dues',
    'venues',
    'partner',
    'clubs',
  ];
  final byId = {for (final item in available) item.id: item};
  return priority
      .toSet()
      .where(byId.containsKey)
      .take(4)
      .map((id) => byId[id]!)
      .toList();
}

List<HomeShortcut> selectedHomeShortcuts(
  QuickAccessPreferences prefs,
  SwanAccess access,
  List<HomeShortcut> available,
) {
  if (prefs.ids == null) return defaultHomeShortcuts(access, available);
  final byId = {for (final item in available) item.id: item};
  return prefs.ids!
      .toSet()
      .where(byId.containsKey)
      .take(4)
      .map((id) => byId[id]!)
      .toList();
}

final availableHomeShortcutsProvider = Provider<List<HomeShortcut>>((ref) {
  final flags = <String>{
    for (final flag
        in homeShortcutCatalog.map((s) => s.flag).whereType<String>())
      if (ref.watch(featureEnabledProvider(flag))) flag,
  };
  return availableHomeShortcuts(
    ref.watch(swanAccessProvider),
    flags,
    allowedRoutes: ref.watch(effectiveAllowedRoutesProvider),
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/account/pro_account_screen.dart';
import '../features/dashboard/pro_dashboard_screen.dart';
import '../features/placeholders/pro_placeholder_screen.dart';
import '../shell/pro_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _panelNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'panelNav');
final _tasksNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'tasksNav');
final _calendarNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'calendarNav');
final _inboxNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'inboxNav');
final _accountNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'accountNav');

final proRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/panel',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ProShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _panelNavigatorKey,
            routes: [
              GoRoute(
                path: '/panel',
                builder: (context, state) => const ProDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _tasksNavigatorKey,
            routes: [
              GoRoute(
                path: '/gorevler',
                builder: (context, state) =>
                    const ProPlaceholderScreen(title: 'Görevler'),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _calendarNavigatorKey,
            routes: [
              GoRoute(
                path: '/takvim',
                builder: (context, state) =>
                    const ProPlaceholderScreen(title: 'Takvim'),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _inboxNavigatorKey,
            routes: [
              GoRoute(
                path: '/gelen-kutusu',
                builder: (context, state) =>
                    const ProPlaceholderScreen(title: 'Gelen Kutusu'),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _accountNavigatorKey,
            routes: [
              GoRoute(
                path: '/hesap',
                builder: (context, state) => const ProAccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

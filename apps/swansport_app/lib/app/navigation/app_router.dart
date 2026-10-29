import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

typedef SwanRouteBuilder = Widget Function(
  BuildContext context,
  GoRouterState state,
);

typedef SwanShellBuilder = Widget Function(
  BuildContext context,
  GoRouterState state,
  StatefulNavigationShell navigationShell,
);

/// Builds the stable four-branch navigation core.
///
/// The production app will adopt this router after every legacy named route
/// has either moved to GoRouter or received an explicit compatibility entry.
/// Keeping the factory independent from feature imports lets the shell and
/// its state-restoration behavior be tested before that cut-over.
GoRouter buildSwanRouter({
  required SwanRouteBuilder feedBuilder,
  required SwanRouteBuilder exploreBuilder,
  required SwanRouteBuilder messagesBuilder,
  required SwanRouteBuilder profileBuilder,
  required SwanShellBuilder shellBuilder,
  GlobalKey<NavigatorState>? navigatorKey,
  String initialLocation = AppRoutes.feed,
  List<RouteBase> routesOutsideShell = const <RouteBase>[],
  SwanRouteBuilder? rootBuilder,
  SwanRouteBuilder? legacyFallbackBuilder,
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
  Widget Function(BuildContext context, GoRouterState state)? errorBuilder,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    observers: observers,
    initialLocation: initialLocation,
    errorBuilder: errorBuilder ??
        (context, state) => SwanRouteNotFound(location: state.uri.toString()),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.root,
        builder: rootBuilder,
        redirect: rootBuilder == null ? (_, __) => AppRoutes.feed : null,
      ),
      GoRoute(
        path: AppRoutes.communities,
        redirect: (_, __) => '${AppRoutes.messages}?tab=communities',
      ),
      StatefulShellRoute.indexedStack(
        builder: shellBuilder,
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: AppRoutes.feed, builder: feedBuilder),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: AppRoutes.explore, builder: exploreBuilder),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: AppRoutes.messages, builder: messagesBuilder),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: AppRoutes.profile, builder: profileBuilder),
            ],
          ),
        ],
      ),
      ...routesOutsideShell,
      if (legacyFallbackBuilder != null)
        GoRoute(
          path: '/:legacyPath(.*)',
          builder: legacyFallbackBuilder,
        ),
    ],
  );
}

class SwanRouteNotFound extends StatelessWidget {
  const SwanRouteNotFound({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sayfa bulunamadı')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.explore_off_rounded, size: 44),
                const SizedBox(height: 12),
                const Text('Bu bağlantı artık kullanılamıyor.'),
                const SizedBox(height: 8),
                Text(location, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.feed),
                  child: const Text('Ana Sayfaya dön'),
                ),
              ],
            ),
          ),
        ),
      );
}

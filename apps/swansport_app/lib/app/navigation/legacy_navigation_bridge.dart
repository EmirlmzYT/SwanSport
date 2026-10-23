import 'package:flutter/material.dart';

import 'shell_navigation_scope.dart';

typedef LegacyRouteFactory = Route<dynamic>? Function(RouteSettings settings);

/// Hosts a legacy Navigator 1 route table inside one GoRouter branch.
///
/// This is deliberately temporary. It keeps existing pushNamed calls working
/// while routes are moved to GoRouter in small, reviewable groups. Each shell
/// branch gets its own bridge and therefore its own legacy back stack.
class LegacyNavigationBridge extends StatelessWidget {
  const LegacyNavigationBridge({
    super.key,
    required this.initialRoute,
    required this.onGenerateRoute,
    this.navigatorKey,
    this.observers = const <NavigatorObserver>[],
    this.suppressEmbeddedBottomNavigation = false,
  });

  final String initialRoute;
  final LegacyRouteFactory onGenerateRoute;
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<NavigatorObserver> observers;
  final bool suppressEmbeddedBottomNavigation;

  @override
  Widget build(BuildContext context) => SwanShellNavigationScope(
        suppressEmbeddedBottomNavigation: suppressEmbeddedBottomNavigation,
        child: Navigator(
          key: navigatorKey,
          initialRoute: initialRoute,
          onGenerateRoute: onGenerateRoute,
          observers: observers,
        ),
      );
}

/// Creates a route factory for a branch root plus the shared legacy factory.
LegacyRouteFactory legacyBranchRouteFactory({
  required String rootLocation,
  required WidgetBuilder rootBuilder,
  required LegacyRouteFactory legacyFactory,
}) {
  return (settings) {
    if (settings.name == rootLocation || settings.name == '/') {
      return MaterialPageRoute<void>(
        settings: RouteSettings(
          name: rootLocation,
          arguments: settings.arguments,
        ),
        builder: rootBuilder,
      );
    }
    return legacyFactory(settings);
  };
}

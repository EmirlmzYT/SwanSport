import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';

import '../widgets/action_gate.dart';
import 'legacy_navigation_bridge.dart';

/// Shared adapter for the existing Navigator 1 route table.
///
/// During migration both MaterialApp and the four branch bridges must apply
/// exactly the same guest/account rules. Keeping that policy here prevents a
/// route from becoming less protected only because it moved under GoRouter.
abstract final class LegacyRouteRegistry {
  static Map<String, WidgetBuilder> protectStaticRoutes(
    Map<String, WidgetBuilder> routes, {
    required bool testCenterEnabled,
    required String testCenterRoute,
  }) {
    return routes.map(
      (route, builder) => MapEntry(
        route,
        (route == testCenterRoute && testCenterEnabled) ||
                SwanAccess.isGuestRoute(route)
            ? builder
            : (context) => AccountRouteGate(builder: builder),
      ),
    );
  }

  static RouteFactory protectDynamicRoutes(RouteFactory factory) =>
      guardAccountRoutes(factory);

  /// Combines the protected static table and dynamic parser for a nested
  /// legacy Navigator used by a StatefulShellRoute branch.
  static LegacyRouteFactory branchFactory({
    required Map<String, WidgetBuilder> routes,
    required RouteFactory onGenerateRoute,
  }) {
    return (settings) {
      final builder = routes[settings.name];
      if (builder != null) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: builder,
        );
      }
      return onGenerateRoute(settings);
    };
  }
}

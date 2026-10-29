import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_navigator.dart';
import 'shell_navigation_scope.dart';
import 'swan_destination.dart';

/// Central navigation helper providing consistent branch-aware navigation.
abstract final class SwanNavigation {
  /// Navigates to [route]. If [route] is a branch root, switches to that branch.
  /// If inside a branch and navigating to a subpage, navigates cleanly.
  static void go(BuildContext context, String route, {Object? extra}) {
    final shellScope = SwanShellNavigationScope.maybeOf(context);
    final branch = SwanShellBranch.fromRoute(route);

    if (shellScope != null && branch != null) {
      shellScope.goBranch(branch.index);
      return;
    }

    final goRouter = GoRouter.maybeOf(context);
    if (goRouter != null) {
      goRouter.go(route, extra: extra);
      return;
    }

    final router = swanGoRouter;
    if (router != null) {
      router.go(route, extra: extra);
      return;
    }

    Navigator.pushNamed(context, route, arguments: extra);
  }

  /// Pushes [route] onto the current navigation stack.
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    String route, {
    Object? extra,
  }) {
    final goRouter = GoRouter.maybeOf(context);
    if (goRouter != null) {
      return goRouter.push<T>(route, extra: extra);
    }

    final router = swanGoRouter;
    if (router != null) {
      return router.push<T>(route, extra: extra);
    }

    return Navigator.pushNamed<T>(context, route, arguments: extra);
  }

  /// Replaces the current route with [route].
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    String route, {
    Object? extra,
    TO? result,
  }) {
    final goRouter = GoRouter.maybeOf(context);
    if (goRouter != null) {
      return goRouter.pushReplacement<T>(route, extra: extra);
    }

    final router = swanGoRouter;
    if (router != null) {
      return router.pushReplacement<T>(route, extra: extra);
    }

    return Navigator.pushReplacementNamed<T, TO>(
      context,
      route,
      arguments: extra,
      result: result,
    );
  }

  /// Pops the topmost route.
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    final goRouter = GoRouter.maybeOf(context);
    if (goRouter != null && goRouter.canPop()) {
      goRouter.pop(result);
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    }
  }
}

extension SwanNavigationExtension on BuildContext {
  void swanGo(String route, {Object? extra}) =>
      SwanNavigation.go(this, route, extra: extra);

  Future<T?> swanPush<T extends Object?>(String route, {Object? extra}) =>
      SwanNavigation.push<T>(this, route, extra: extra);

  Future<T?> swanPushReplacement<T extends Object?, TO extends Object?>(
    String route, {
    Object? extra,
    TO? result,
  }) =>
      SwanNavigation.pushReplacement<T, TO>(
        this,
        route,
        extra: extra,
        result: result,
      );

  void swanPop<T extends Object?>([T? result]) =>
      SwanNavigation.pop<T>(this, result);
}

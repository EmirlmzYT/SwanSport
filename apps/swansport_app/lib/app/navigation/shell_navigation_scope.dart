import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Tells screens hosted by AppShell that the persistent bottom navigation is
/// already rendered by the shell.
class SwanShellNavigationScope extends InheritedWidget {
  const SwanShellNavigationScope({
    super.key,
    required super.child,
    this.suppressEmbeddedBottomNavigation = true,
    this.navigationShell,
    this.onReselect,
  });

  final bool suppressEmbeddedBottomNavigation;
  final StatefulNavigationShell? navigationShell;
  final ValueChanged<int>? onReselect;

  static SwanShellNavigationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SwanShellNavigationScope>();

  static bool suppressEmbeddedOf(BuildContext context) =>
      maybeOf(context)?.suppressEmbeddedBottomNavigation ?? false;

  void goBranch(int index) {
    final shell = navigationShell;
    if (shell == null) return;
    final reselect = shell.currentIndex == index;
    if (reselect) onReselect?.call(index);
    shell.goBranch(index, initialLocation: reselect);
  }

  @override
  bool updateShouldNotify(SwanShellNavigationScope oldWidget) =>
      suppressEmbeddedBottomNavigation !=
          oldWidget.suppressEmbeddedBottomNavigation ||
      navigationShell != oldWidget.navigationShell ||
      onReselect != oldWidget.onReselect;
}

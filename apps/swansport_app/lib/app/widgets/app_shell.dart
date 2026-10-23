import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/shell_navigation_scope.dart';
import '../navigation/swan_destination.dart';
import 'swan_bottom_nav.dart';

/// Persistent application chrome around the four main navigation branches.
class SwanAppShell extends StatelessWidget {
  const SwanAppShell({
    super.key,
    required this.navigationShell,
    this.bottomNavigationBar = const SwanBottomNav(),
    this.onReselect,
  });

  final StatefulNavigationShell navigationShell;
  final Widget bottomNavigationBar;
  final ValueChanged<int>? onReselect;

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.maybeOf(context)
        ?.routeInformationProvider
        .value
        .uri
        .path;
    final hideNav = SwanDestination.shouldHideBottomNav(location);
    final isRootBranch = navigationShell.currentIndex == 0;

    return PopScope(
      canPop: isRootBranch,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: SwanShellNavigationScope(
        suppressEmbeddedBottomNavigation: false,
        navigationShell: navigationShell,
        onReselect: onReselect,
        child: Scaffold(
          extendBody: true,
          body: navigationShell,
          bottomNavigationBar:
              hideNav ? const SizedBox.shrink() : bottomNavigationBar,
        ),
      ),
    );
  }
}

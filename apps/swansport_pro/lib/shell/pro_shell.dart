import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../workspaces/pro_workspace_switcher.dart';
import '../workspaces/pro_workspace_controller.dart';
import '../features/operations/pro_club_context_selector.dart';
import 'pro_navigation.dart';

class ProShell extends ConsumerWidget {
  const ProShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 20,
              color: Color(0xFF38BDF8),
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'SwanSport Pro',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (workspace?.supportsClubOperations ?? false)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: const ProClubContextSelector(),
            ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: ProWorkspaceSwitcher(),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: ProBottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

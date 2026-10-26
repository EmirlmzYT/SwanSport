import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../workspaces/pro_workspace_switcher.dart';
import 'pro_navigation.dart';

class ProShell extends StatelessWidget {
  const ProShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
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
        actions: const [
          Padding(
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

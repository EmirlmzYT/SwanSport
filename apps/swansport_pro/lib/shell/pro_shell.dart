import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../workspaces/pro_workspace_switcher.dart';
import '../workspaces/pro_workspace_controller.dart';
import '../workspaces/pro_workspace.dart';
import '../features/operations/pro_club_context_selector.dart';
import '../app/pro_theme.dart';
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
    void selectDestination(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopShell = constraints.maxWidth >= 960;
        if (useDesktopShell) {
          return Scaffold(
            body: Row(
              children: [
                _ProDesktopNavigation(
                  currentIndex: navigationShell.currentIndex,
                  onDestinationSelected: selectDestination,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      _ProTopBar(workspace: workspace),
                      Expanded(child: navigationShell),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: const _ProBrand(compact: true),
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
            onDestinationSelected: selectDestination,
          ),
        );
      },
    );
  }
}

class _ProTopBar extends StatelessWidget {
  const _ProTopBar({required this.workspace});

  final ProWorkspace? workspace;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: ProTheme.background,
        border: Border(bottom: BorderSide(color: ProTheme.line)),
      ),
      child: Row(
        children: [
          Text(
            '${workspace?.label ?? 'Operasyon'} Merkezi',
            style: const TextStyle(
              color: ProTheme.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (workspace?.supportsClubOperations ?? false) ...[
            const SizedBox(width: 220, child: ProClubContextSelector()),
            const SizedBox(width: 12),
          ],
          const ProWorkspaceSwitcher(),
        ],
      ),
    );
  }
}

class _ProDesktopNavigation extends StatelessWidget {
  const _ProDesktopNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      color: ProTheme.surface,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: _ProBrand(),
          ),
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'ÇALIŞMA ALANI',
              style: TextStyle(
                color: ProTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < proNavigationItems.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _DesktopDestination(
                item: proNavigationItems[i],
                selected: currentIndex == i,
                onTap: () => onDestinationSelected(i),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ProTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ProTheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: ProTheme.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yetkiler sunucuda doğrulanır',
                    style: TextStyle(
                      color: ProTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopDestination extends StatelessWidget {
  const _DesktopDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ProNavigationItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: selected
            ? ProTheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected ? ProTheme.primary : ProTheme.muted,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? ProTheme.ink : ProTheme.muted,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ProTheme.primary,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProBrand extends StatelessWidget {
  const _ProBrand({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ProTheme.primary, ProTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 11 : 13),
          ),
          child: Icon(
            Icons.sports_rounded,
            size: compact ? 19 : 22,
            color: const Color(0xFF03201D),
          ),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'SwanSport Pro',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ProTheme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import '../features/operations/pro_tasks_controller.dart';
import '../app/pro_theme.dart';
import '../widgets/pro_context_bar.dart';
import 'pro_navigation.dart';

class ProShell extends ConsumerWidget {
  const ProShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadInbox =
        ref.watch(proUnreadNotificationsCountProvider).valueOrNull ?? 0;
    final pendingTasks =
        ref.watch(proPendingTasksCountProvider).valueOrNull ?? 0;

    int? badgeForIndex(int index) {
      if (index == 1) return pendingTasks > 0 ? pendingTasks : null;
      if (index == 3) return unreadInbox > 0 ? unreadInbox : null;
      return null;
    }

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
                  badgeForIndex: badgeForIndex,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      const ProContextBar(),
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
          ),
          body: Column(
            children: [
              const ProContextBar(compact: true),
              Expanded(child: navigationShell),
            ],
          ),
          bottomNavigationBar: ProBottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onDestinationSelected: selectDestination,
            badgeForIndex: badgeForIndex,
          ),
        );
      },
    );
  }
}

class _ProDesktopNavigation extends StatelessWidget {
  const _ProDesktopNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    this.badgeForIndex,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final int? Function(int index)? badgeForIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      color: ProTheme.surface,
      child: SafeArea(
        child: SingleChildScrollView(
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
                    badgeCount: badgeForIndex?.call(i),
                  ),
                ),
              const SizedBox(height: 24),
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
                    Icon(
                      Icons.verified_user_outlined,
                      color: ProTheme.primary,
                    ),
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
        ),
      ),
    );
  }
}

class _DesktopDestination extends StatelessWidget {
  const _DesktopDestination({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final ProNavigationItemData item;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount != null && badgeCount! > 0;
    final semanticLabel =
        hasBadge ? '${item.label}, $badgeCount bildirim' : item.label;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
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
                if (hasBadge) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badgeCount! > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
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

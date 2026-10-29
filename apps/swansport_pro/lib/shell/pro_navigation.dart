import 'package:flutter/material.dart';

import '../app/pro_theme.dart';

class ProNavigationItemData {
  const ProNavigationItemData({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const proNavigationItems = <ProNavigationItemData>[
  ProNavigationItemData(
    route: '/panel',
    label: 'Panel',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  ProNavigationItemData(
    route: '/gorevler',
    label: 'Görevler',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
  ),
  ProNavigationItemData(
    route: '/takvim',
    label: 'Takvim',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
  ProNavigationItemData(
    route: '/gelen-kutusu',
    label: 'Gelen Kutusu',
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox,
  ),
  ProNavigationItemData(
    route: '/hesap',
    label: 'Hesap',
    icon: Icons.manage_accounts_outlined,
    selectedIcon: Icons.manage_accounts,
  ),
];

class ProNavigationItem extends StatelessWidget {
  const ProNavigationItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final ProNavigationItemData item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = ProTheme.primary;
    const inactiveColor = ProTheme.muted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? ProTheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProBottomNavigationBar extends StatelessWidget {
  const ProBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        decoration: BoxDecoration(
          color: ProTheme.surface.withValues(alpha: 0.98),
          border: Border.all(color: ProTheme.line),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < proNavigationItems.length; i++)
              Expanded(
                child: ProNavigationItem(
                  item: proNavigationItems[i],
                  isSelected: currentIndex == i,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

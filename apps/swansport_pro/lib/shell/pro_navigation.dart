import 'package:flutter/material.dart';

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
    final activeColor = const Color(0xFF38BDF8);
    final inactiveColor = const Color(0xFF94A3B8);

    return Semantics(
      button: true,
      selected: isSelected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C2541),
        border: Border(
          top: BorderSide(color: Color(0xFF3A4B75), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
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
    );
  }
}

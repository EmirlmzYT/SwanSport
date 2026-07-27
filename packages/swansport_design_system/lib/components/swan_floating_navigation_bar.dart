import 'dart:ui';
import 'package:flutter/material.dart';
import '../foundations/colors/swan_colors.dart';

class SwanFloatingNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<SwanNavigationDestination> destinations;

  const SwanFloatingNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? SwanColors.darkPrimary : SwanColors.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 22, bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: isDark
                    ? SwanColors.darkSurface.withValues(alpha: 0.88)
                    : SwanColors.surface.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2E3440).withValues(alpha: 0.8)
                      : SwanColors.outline.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.09),
                    blurRadius: 26,
                    offset: const Offset(0, 9),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(destinations.length, (index) {
                  final item = destinations[index];
                  final isSelected = selectedIndex == index;

                  return GestureDetector(
                    onTap: () => onDestinationSelected(index),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 12 : 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: isSelected
                                ? activeColor
                                : (isDark
                                    ? SwanColors.darkText
                                        .withValues(alpha: 0.45)
                                    : SwanColors.textSecondary
                                        .withValues(alpha: 0.7)),
                          ),
                          // Label animasyonu: yalnızca seçili sekme gösterir
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: isSelected
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 7),
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: activeColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SwanNavigationDestination {
  final IconData icon;
  final String label;

  const SwanNavigationDestination({
    required this.icon,
    required this.label,
  });
}

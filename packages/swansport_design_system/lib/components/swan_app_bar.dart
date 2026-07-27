import 'package:flutter/material.dart';
import '../foundations/colors/swan_colors.dart';
import 'swan_context_switcher.dart';

class SwanAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? clubName;
  final String? roleName;
  final VoidCallback? onContextTap;
  final Widget? leading;
  final List<Widget>? actions;

  const SwanAppBar({
    super.key,
    this.title,
    this.clubName,
    this.roleName,
    this.onContextTap,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? SwanColors.darkSurface : SwanColors.surface;
    final border = isDark ? const Color(0xFF2E3440) : SwanColors.outline;

    Widget centerTitle;
    if (clubName != null && roleName != null) {
      centerTitle = SwanContextSwitcher(
        clubName: clubName!,
        roleName: roleName!,
        onTap: onContextTap,
      );
    } else {
      centerTitle = Text(
        title ?? 'SwanSport',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: isDark ? SwanColors.darkText : SwanColors.textPrimary,
        ),
      );
    }

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            leading ??
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? SwanColors.darkPrimary : SwanColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: centerTitle),
            ),
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}

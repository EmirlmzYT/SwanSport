import 'package:flutter/material.dart';
import '../foundations/colors/swan_colors.dart';

class SwanContextSwitcher extends StatelessWidget {
  final String clubName;
  final String roleName;
  final VoidCallback? onTap;

  const SwanContextSwitcher({
    super.key,
    required this.clubName,
    required this.roleName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF123736) : SwanColors.primaryContainer;
    final fg = isDark ? SwanColors.darkPrimary : SwanColors.primary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: fg.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🏀 ',
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              Flexible(
                child: Text(
                  clubName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  ' • $roleName',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

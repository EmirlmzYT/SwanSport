import 'package:flutter/material.dart';
import '../foundations/colors/swan_colors.dart';

class SwanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderSide? border;
  final List<BoxShadow>? boxShadow;
  final double borderRadius;

  const SwanCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? SwanColors.darkSurface : SwanColors.surface;
    final defaultBorder = BorderSide(
      color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
      width: 1,
    );

    final defaultShadow = [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : const Color(0xFF111827).withValues(alpha: 0.04),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ];

    final cardChild = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.fromBorderSide(border ?? defaultBorder),
        boxShadow: boxShadow ?? defaultShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: cardChild,
      );
    }

    return cardChild;
  }
}

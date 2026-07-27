import 'package:flutter/material.dart';
import '../foundations/colors/swan_colors.dart';

enum SwanButtonType { primary, secondary, text, destructive }

class SwanButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SwanButtonType type;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const SwanButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = SwanButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
  });

  const SwanButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
  }) : type = SwanButtonType.primary;

  const SwanButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
  }) : type = SwanButtonType.secondary;

  const SwanButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 48,
  }) : type = SwanButtonType.destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;
    List<BoxShadow>? shadow;

    switch (type) {
      case SwanButtonType.primary:
        bg = isDark ? SwanColors.darkPrimary : SwanColors.primary;
        fg = isDark ? Colors.black : Colors.white;
        shadow = [
          BoxShadow(
            color: bg.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ];
        break;
      case SwanButtonType.secondary:
        bg = isDark ? SwanColors.darkSurfaceVariant : SwanColors.surfaceVariant;
        fg = isDark ? SwanColors.darkText : SwanColors.textPrimary;
        border = BorderSide(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFEAEFF2),
        );
        break;
      case SwanButtonType.text:
        bg = Colors.transparent;
        fg = isDark ? SwanColors.darkPrimary : SwanColors.primary;
        break;
      case SwanButtonType.destructive:
        bg = SwanColors.error;
        fg = Colors.white;
        shadow = [
          BoxShadow(
            color: SwanColors.error.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ];
        break;
    }

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: onPressed == null ? bg.withValues(alpha: 0.4) : bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(border),
          boxShadow: onPressed == null ? null : shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

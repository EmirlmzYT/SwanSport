import 'package:flutter/material.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Ana mobil ekranlarda ortak başlık hiyerarşisi.
///
/// Profil avatarı burada gezinme hedefi değildir; Profil zaten sabit alt
/// menüdedir. Başlık yalnızca ekran kimliği, geri eylemi ve ekrana özgü
/// gerçek aksiyonları taşır.
class SwanPageHeader extends StatelessWidget {
  const SwanPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
      padding: const EdgeInsets.fromLTRB(
        SwanSpace.md,
        SwanSpace.sm,
        SwanSpace.sm,
        SwanSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: c.isDark ? .92 : .96),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? .16 : .045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            _HeaderAction(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Geri',
              onTap: onBack!,
            ),
            const SizedBox(width: SwanSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.h2(c.ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: SwanSpace.sm),
            ...actions,
          ],
        ],
      ),
    );
  }
}

class SwanHeaderAction extends StatelessWidget {
  const SwanHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _HeaderAction(
        icon: icon,
        tooltip: tooltip,
        onTap: onTap,
      );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
              border: Border.all(color: c.line),
            ),
            child: Icon(icon, size: 19, color: c.ink),
          ),
        ),
      ),
    );
  }
}

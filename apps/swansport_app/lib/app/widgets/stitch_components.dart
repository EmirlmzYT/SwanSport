import 'package:flutter/material.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import 'premium.dart';

class StitchTopBar extends StatelessWidget {
  const StitchTopBar({
    super.key,
    this.subtitle = 'CLUB OPS & NETWORK',
    this.actions = const [],
    this.trailing,
  });

  final String subtitle;
  final List<Widget> actions;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: c.isDark ? .90 : .96),
        border: Border(bottom: BorderSide(color: c.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? .18 : .035),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentFill,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Text('S', style: SwanType.h2(Colors.white)),
          ),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SwanSport', style: SwanType.h3(c.ink)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                ),
              ],
            ),
          ),
          ...actions,
          if (trailing != null) ...[
            const SizedBox(width: SwanSpace.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class StitchSectionTitle extends StatelessWidget {
  const StitchSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      SwanSpace.lg,
      0,
      SwanSpace.lg,
      SwanSpace.sm,
    ),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 18,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SwanType.h3(c.ink),
            ),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!),
                  const Icon(Icons.chevron_right_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class StitchSearchBar extends StatelessWidget {
  const StitchSearchBar({
    super.key,
    required this.hint,
    required this.onTap,
    this.onFilter,
  });

  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
                  const SizedBox(width: SwanSpace.md),
                  Expanded(
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.body(c.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onFilter != null) ...[
          const SizedBox(width: SwanSpace.sm),
          InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(Icons.tune_rounded, size: 20, color: c.ink),
            ),
          ),
        ],
      ],
    );
  }
}

class StitchInlineSearchField extends StatelessWidget {
  const StitchInlineSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.onFilter,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: c.inkMuted),
                const SizedBox(width: SwanSpace.md),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: hint,
                      hintStyle: SwanType.body(c.inkMuted),
                    ),
                    style: SwanType.body(c.ink, w: FontWeight.w600),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: c.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (onFilter != null) ...[
          const SizedBox(width: SwanSpace.sm),
          InkWell(
            onTap: onFilter,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(Icons.tune_rounded, size: 20, color: c.ink),
            ),
          ),
        ],
      ],
    );
  }
}

class StitchHeroCard extends StatelessWidget {
  const StitchHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.meta,
    this.actionLabel,
    this.onAction,
    this.tone,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final String? meta;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final color = tone ?? c.accent;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: c.isDark ? .16 : .04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 128,
              width: double.infinity,
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: .86),
                    c.accentFill.withValues(alpha: .70),
                    const Color(0xFF111827),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    bottom: -10,
                    child: Icon(
                      icon,
                      size: 82,
                      color: Colors.white.withValues(alpha: .15),
                    ),
                  ),
                  if (badge != null)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .90),
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Text(
                          badge!,
                          style: SwanType.caption(color, w: FontWeight.w800),
                        ),
                      ),
                    ),
                  if (meta != null)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        meta!,
                        style:
                            SwanType.caption(Colors.white, w: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.body(c.ink, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(c.inkMuted),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: SwanSpace.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StitchRail extends StatelessWidget {
  const StitchRail({
    super.key,
    required this.children,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
    this.gap = SwanSpace.md,
  });

  final List<Widget> children;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: padding,
      itemCount: children.length,
      separatorBuilder: (_, __) => SizedBox(width: gap),
      itemBuilder: (_, index) => children[index],
    );
    return height == null ? list : SizedBox(height: height, child: list);
  }
}

class StitchActionTile extends StatelessWidget {
  const StitchActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SwanSpace.lg,
          vertical: SwanSpace.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Icon(icon, color: c.accent, size: 21),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SwanType.body(c.ink, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: c.inkMuted,
                ),
          ],
        ),
      ),
    );
  }
}

class StitchMiniStat extends StatelessWidget {
  const StitchMiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return SwanMetricCard(
      item: SwanMetricItem(
        label: label,
        value: value,
        icon: icon,
        tone: tone,
      ),
    );
  }
}

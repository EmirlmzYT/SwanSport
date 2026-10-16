import 'package:flutter/material.dart';
import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

class SwanSurface extends StatelessWidget {
  const SwanSurface({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: SwanSpace.md),
    child: Material(color: context.swan.surface, clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.lg),
        side: BorderSide(color: context.swan.line)),
      child: Padding(padding: const EdgeInsets.all(SwanSpace.lg), child: child)),
  );
}

class SwanActionCard extends StatelessWidget {
  const SwanActionCard({required this.title, required this.icon, required this.onTap, this.subtitle, super.key});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Padding(padding: const EdgeInsets.only(bottom: SwanSpace.sm), child: Material(
      color: c.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md),
        side: BorderSide(color: c.line)), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(SwanSpace.md),
        child: Row(children: [
          Container(width: SwanSpace.xl + SwanSpace.md, height: SwanSpace.xl + SwanSpace.md,
            decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(SwanRadius.sm)),
            child: Icon(icon, color: c.inkMuted)),
          const SizedBox(width: SwanSpace.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: SwanType.body(c.ink, w: FontWeight.w600)),
            if (subtitle != null) Text(subtitle!, style: SwanType.caption(c.inkMuted)),
          ])),
          Icon(Icons.chevron_right_rounded, color: c.inkMuted),
        ]))),
    ));
  }
}

/// Themed information/action row that can also carry a rich result subtitle.
class SwanInfoRow extends StatelessWidget {
  const SwanInfoRow({required this.title, this.subtitle, this.leading, this.trailing, this.onTap, super.key});
  final Widget title;
  final Widget? subtitle, leading, trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return SwanSurface(child: InkWell(onTap: onTap,
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: SwanSpace.xl * 2), child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: SwanSpace.md)],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DefaultTextStyle(style: SwanType.body(c.ink), child: title),
          if (subtitle != null) DefaultTextStyle(style: SwanType.caption(c.inkMuted), child: subtitle!),
        ])),
        if (trailing != null) trailing!
        else if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.inkMuted),
      ]))));
  }
}

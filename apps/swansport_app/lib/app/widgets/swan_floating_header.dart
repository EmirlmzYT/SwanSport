import 'package:flutter/material.dart';
import '../design/swan_chrome.dart';
import '../design/swan_palette.dart';
import '../design/swan_shape.dart';

/// Compact independent controls, not a full-width frosted toolbar panel.
class SwanHeaderControl extends StatelessWidget {
  const SwanHeaderControl({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final opaque = MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    final decoration = BoxDecoration(
      color: c.surface
          .withValues(alpha: opaque ? 1 : SwanChrome.headerControlTint),
      borderRadius: BorderRadius.circular(SwanChrome.capsuleRadius),
      border: Border.all(
          width: SwanChrome.rimWidth,
          color: c.ink.withValues(alpha: c.isDark ? .13 : .08)),
    );
    return DecoratedBox(
        decoration: decoration,
        child: SizedBox.square(
            dimension: SwanChrome.headerControlDiameter,
            child: Center(child: child)));
  }
}

class SwanHeaderIconButton extends StatelessWidget {
  const SwanHeaderIconButton(
      {required this.icon,
      required this.tooltip,
      required this.onPressed,
      super.key});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onPressed,
        child: Tooltip(
            message: tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: SizedBox.square(
                  dimension: SwanChrome.touchTarget,
                  child: Center(
                      child: SwanHeaderControl(
                          child: Icon(icon,
                              size: SwanChrome.headerIconSize,
                              color: context.swan.ink)))),
            )),
      );
}

/// Symmetric title reservation keeps the title at the screen's actual center.
class SwanFloatingHeader extends StatelessWidget {
  const SwanFloatingHeader(
      {required this.title, this.leading, this.actions = const [], super.key});
  final Widget title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: SwanChrome.headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.sm),
          child: Stack(alignment: Alignment.center, children: [
            Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: SwanChrome.headerSideExtent),
                child: Center(
                    child: DefaultTextStyle.merge(
                        style: TextStyle(shadows: [
                          Shadow(
                              color: context.swan.bg.withValues(alpha: .55),
                              blurRadius: SwanSpace.xs)
                        ]),
                        child: title))),
            if (leading != null)
              Align(
                  alignment: AlignmentDirectional.centerStart, child: leading),
            Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions)),
          ]),
        ),
      );
}

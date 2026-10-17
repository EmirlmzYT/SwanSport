import 'dart:ui';
import 'package:flutter/material.dart';
import '../design/swan_chrome.dart';
import '../design/swan_palette.dart';

/// Route-local state: no role, route or data-provider responsibilities.
class ScrollChromeController extends ChangeNotifier {
  bool _compact = false;
  double _travel = 0;
  bool get compact => _compact;
  void reset() {
    _travel = 0;
    if (!_compact) return;
    _compact = false;
    notifyListeners();
  }

  void travel(double delta) {
    if (!delta.isFinite || delta == 0) return;
    if ((_travel > 0 && delta < 0) || (_travel < 0 && delta > 0)) _travel = 0;
    _travel += delta;
    if (!_compact && _travel >= SwanChrome.hideTravel) {
      _compact = true;
      _travel = 0;
      notifyListeners();
    } else if (_compact && _travel <= -SwanChrome.revealTravel) {
      _compact = false;
      _travel = 0;
      notifyListeners();
    }
  }

  bool onScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axisDirection != AxisDirection.down) return false;
    if (notification.metrics.pixels <= notification.metrics.minScrollExtent) {
      reset();
      return false;
    }
    // Ignore nested lists, ballistic bounce and programmatic scrolling.
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        !notification.metrics.outOfRange) travel(notification.scrollDelta ?? 0);
    return false; // Preserve RefreshIndicator and other scroll listeners.
  }
}

class ScrollChromeScope extends InheritedNotifier<ScrollChromeController> {
  const ScrollChromeScope(
      {required ScrollChromeController controller,
      required super.child,
      super.key})
      : super(notifier: controller);
  static ScrollChromeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScrollChromeScope>()?.notifier;
}

/// A bounded blur, not a full-screen filter. Accessibility can make it opaque.
class SwanGlassSurface extends StatelessWidget {
  const SwanGlassSurface(
      {required this.child, this.floating = false, super.key});
  final Widget child;
  final bool floating;
  @override
  Widget build(BuildContext context) {
    if (!floating) return _SwanHeaderSurface(child: child);
    final c = context.swan;
    final opaque = MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    final radius =
        BorderRadius.circular(floating ? SwanChrome.capsuleRadius : 0);
    final fill = opaque
        ? c.surface
        : floating
            ? c.surface.withValues(alpha: c.isDark ? .88 : .84)
            : null;
    return DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: floating
              ? [
                  BoxShadow(
                      color: c.ink.withValues(alpha: c.isDark ? .12 : .07),
                      blurRadius: SwanChrome.shadowBlur,
                      offset: const Offset(0, SwanChrome.shadowTravel)),
                ]
              : null),
      child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            enabled: !opaque,
            filter: ImageFilter.blur(
                sigmaX: floating ? SwanChrome.blur : SwanChrome.headerBlur,
                sigmaY: floating ? SwanChrome.blur : SwanChrome.headerBlur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                  color: fill,
                  borderRadius: radius,
                  border: floating
                      ? Border.all(
                          width: SwanChrome.rimWidth,
                          color: c.isDark
                              ? c.ink.withValues(alpha: .14)
                              : c.surface.withValues(alpha: .92))
                      : null),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          )),
    );
  }
}

/// Narrow non-overlapping strips approximate the reference's progressive
/// scroll-edge diffusion. No shader-mask/saveLayer enclosing a backdrop filter,
/// no full-screen blur and no tinted rectangular toolbar sheet.
class _SwanHeaderSurface extends StatelessWidget {
  const _SwanHeaderSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opaque = MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    if (opaque) return Material(color: context.swan.surface, child: child);
    return Stack(fit: StackFit.passthrough, children: [
      Positioned.fill(
          child: IgnorePointer(
              child: Column(children: [
        for (final sigma in SwanChrome.headerEdgeBlurs)
          Expanded(
              child: ClipRect(
                  child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: const SizedBox.expand(),
          ))),
      ]))),
      Material(type: MaterialType.transparency, child: child),
    ]);
  }
}

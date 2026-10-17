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
                  gradient: !floating && !opaque
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [
                              0,
                              .75,
                              1
                            ],
                          colors: [
                              c.surface.withValues(
                                  alpha: c.isDark
                                      ? SwanChrome.headerDarkTintTop
                                      : SwanChrome.headerTintTop),
                              c.surface.withValues(
                                  alpha: c.isDark
                                      ? SwanChrome.headerDarkTintMiddle
                                      : SwanChrome.headerTintMiddle),
                              c.surface.withValues(
                                  alpha: SwanChrome.headerTintBottom),
                            ])
                      : null,
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

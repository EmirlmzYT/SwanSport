import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import '../design/swan_shape.dart';

import '../design/swan_chrome.dart';
import 'scroll_chrome.dart';
import 'swan_bottom_nav.dart';

/// One controller per screen, including screens opened with unnamed routes.
/// This owns presentation only; form state, navigation and access stay put.
class SwanScaffold extends StatefulWidget {
  const SwanScaffold(
      {super.key,
      this.appBar,
      this.header,
      this.body,
      this.bottomNavigationBar,
      this.backgroundColor,
      this.floatingActionButton,
      this.floatingActionButtonLocation,
      this.floatingActionButtonAnimator,
      this.persistentFooterButtons,
      this.persistentFooterAlignment = AlignmentDirectional.centerEnd,
      this.drawer,
      this.onDrawerChanged,
      this.endDrawer,
      this.onEndDrawerChanged,
      this.bottomSheet,
      this.resizeToAvoidBottomInset,
      this.primary = true,
      this.drawerDragStartBehavior = DragStartBehavior.start,
      this.extendBody = false,
      this.extendBodyBehindAppBar = false,
      this.drawerScrimColor,
      this.drawerEdgeDragWidth,
      this.drawerEnableOpenDragGesture = true,
      this.endDrawerEnableOpenDragGesture = true,
      this.restorationId});

  final PreferredSizeWidget? appBar;

  /// Existing bespoke headers keep their natural, text-scaled height.
  final Widget? header;
  final Widget? body,
      bottomNavigationBar,
      floatingActionButton,
      drawer,
      endDrawer,
      bottomSheet;
  final Color? backgroundColor, drawerScrimColor;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget>? persistentFooterButtons;
  final AlignmentDirectional persistentFooterAlignment;
  final DrawerCallback? onDrawerChanged, onEndDrawerChanged;
  final bool? resizeToAvoidBottomInset;
  final bool primary,
      extendBody,
      extendBodyBehindAppBar,
      drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture;
  final DragStartBehavior drawerDragStartBehavior;
  final double? drawerEdgeDragWidth;
  final String? restorationId;

  @override
  State<SwanScaffold> createState() => _SwanScaffoldState();
}

class _SwanScaffoldState extends State<SwanScaffold> {
  final _chrome = ScrollChromeController();
  double _headerHeight = SwanChrome.headerHeight;

  void _measureHeader(double height) {
    if (!mounted || !height.isFinite || height == _headerHeight) return;
    setState(() => _headerHeight = height);
  }

  @override
  void dispose() {
    _chrome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScrollChromeScope(
        controller: _chrome,
        child: Builder(builder: (context) {
          final chrome = ScrollChromeScope.maybeOf(context)!;
          final reducedMotion = MediaQuery.disableAnimationsOf(context);
          final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
          final hidden = chrome.compact && !reducedMotion && !keyboard;
          final bar = widget.appBar ??
              (widget.header == null
                  ? null
                  : PreferredSize(
                      preferredSize: Size.fromHeight(_headerHeight),
                      child: _MeasuredHeader(
                          onHeight: _measureHeader, child: widget.header!),
                    ));
          final preferredHeight = bar is AppBar
              ? AppBar.preferredHeightFor(context, bar.preferredSize)
              : bar?.preferredSize.height ?? 0;
          // The full-height hit/viewport reservation is stable while the capsule
          // animates, so list extent and forms cannot jump under the user's finger.
          final bottom = widget.bottomNavigationBar;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: hidden ? 0 : 1),
            duration: reducedMotion ? Duration.zero : SwanChrome.duration,
            curve: Curves.easeOutCubic,
            builder: (context, reveal, _) => Scaffold(
              appBar: bar == null
                  ? null
                  : PreferredSize(
                      preferredSize: Size.fromHeight(preferredHeight * reveal),
                      child: SizedBox(
                        height: preferredHeight * reveal +
                            (widget.primary
                                ? MediaQuery.paddingOf(context).top
                                : 0),
                        child: ClipRect(
                            child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: preferredHeight +
                              (widget.primary
                                  ? MediaQuery.paddingOf(context).top
                                  : 0),
                          maxHeight: preferredHeight +
                              (widget.primary
                                  ? MediaQuery.paddingOf(context).top
                                  : 0),
                          child: IgnorePointer(
                              ignoring: hidden,
                              child: ExcludeSemantics(
                                  excluding: hidden,
                                  child: Transform.translate(
                                    offset: Offset(
                                        0, -preferredHeight * (1 - reveal)),
                                    child: _glassAppBar(bar),
                                  ))),
                        )),
                      ),
                    ),
              body: NotificationListener<ScrollNotification>(
                  onNotification: _chrome.onScroll,
                  child: widget.body ?? const SizedBox.shrink()),
              bottomNavigationBar: bottom is SwanBottomNav
                  ? keyboard
                      ? null
                      : SizedBox(
                          height: SwanChrome.expandedHeight +
                              SwanChrome.bottomGap +
                              SwanSpace.xs +
                              MediaQuery.paddingOf(context).bottom,
                          child: Align(
                              alignment: Alignment.bottomCenter, child: bottom))
                  : bottom,
              backgroundColor: widget.backgroundColor,
              floatingActionButton: widget.floatingActionButton,
              floatingActionButtonLocation: widget.floatingActionButtonLocation,
              floatingActionButtonAnimator: widget.floatingActionButtonAnimator,
              persistentFooterButtons: widget.persistentFooterButtons,
              persistentFooterAlignment: widget.persistentFooterAlignment,
              drawer: widget.drawer,
              onDrawerChanged: widget.onDrawerChanged,
              endDrawer: widget.endDrawer,
              onEndDrawerChanged: widget.onEndDrawerChanged,
              bottomSheet: widget.bottomSheet,
              resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
              primary: widget.primary,
              drawerDragStartBehavior: widget.drawerDragStartBehavior,
              extendBody: widget.extendBody,
              extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
              drawerScrimColor: widget.drawerScrimColor,
              drawerEdgeDragWidth: widget.drawerEdgeDragWidth,
              drawerEnableOpenDragGesture: widget.drawerEnableOpenDragGesture,
              endDrawerEnableOpenDragGesture:
                  widget.endDrawerEnableOpenDragGesture,
              restorationId: widget.restorationId,
            ),
          );
        }),
      );

  Widget _glassAppBar(PreferredSizeWidget bar) {
    if (bar is! AppBar)
      return SwanGlassSurface(child: SafeArea(bottom: false, child: bar));
    // Preserve every functional AppBar slot (tabs, search, back, save, drawer).
    return SwanGlassSurface(
        child: AppBar(
      key: bar.key,
      leading: bar.leading,
      automaticallyImplyLeading: bar.automaticallyImplyLeading,
      title: bar.title,
      actions: bar.actions,
      automaticallyImplyActions: bar.automaticallyImplyActions,
      flexibleSpace: bar.flexibleSpace,
      bottom: bar.bottom,
      elevation: 0,
      scrolledUnderElevation: 0,
      notificationPredicate: bar.notificationPredicate,
      shadowColor: bar.shadowColor,
      surfaceTintColor: Colors.transparent,
      shape: bar.shape,
      backgroundColor: Colors.transparent,
      foregroundColor: bar.foregroundColor,
      iconTheme: bar.iconTheme,
      actionsIconTheme: bar.actionsIconTheme,
      primary: bar.primary,
      centerTitle: bar.centerTitle,
      excludeHeaderSemantics: bar.excludeHeaderSemantics,
      titleSpacing: bar.titleSpacing,
      toolbarOpacity: bar.toolbarOpacity,
      bottomOpacity: bar.bottomOpacity,
      toolbarHeight: bar.toolbarHeight,
      leadingWidth: bar.leadingWidth,
      toolbarTextStyle: bar.toolbarTextStyle,
      titleTextStyle: bar.titleTextStyle,
      systemOverlayStyle: bar.systemOverlayStyle,
      forceMaterialTransparency: true,
      useDefaultSemanticsOrder: bar.useDefaultSemanticsOrder,
      clipBehavior: bar.clipBehavior,
      actionsPadding: bar.actionsPadding,
    ));
  }
}

class _MeasuredHeader extends SingleChildRenderObjectWidget {
  const _MeasuredHeader({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HeaderLayout(onHeight);
  @override
  void updateRenderObject(
      BuildContext context, covariant _HeaderLayout renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _HeaderLayout extends RenderProxyBox {
  _HeaderLayout(this.onHeight);
  ValueChanged<double> onHeight;
  double? _reported;
  @override
  void performLayout() {
    child!.layout(constraints.loosen().copyWith(maxHeight: double.infinity),
        parentUsesSize: true);
    size = constraints.constrain(child!.size);
    final height = child!.size.height;
    if (_reported == height) return;
    _reported = height;
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}

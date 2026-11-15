import 'package:flutter/material.dart';

/// Platformun doğal dokunma, sürükleme ve fling davranışını korur.
class SwanScrollBehavior extends MaterialScrollBehavior {
  const SwanScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    const alwaysScrollable = AlwaysScrollableScrollPhysics();
    return switch (getPlatform(context)) {
      TargetPlatform.iOS ||
      TargetPlatform.macOS =>
        const BouncingScrollPhysics(parent: alwaysScrollable),
      TargetPlatform.android ||
      TargetPlatform.fuchsia =>
        const ClampingScrollPhysics(parent: alwaysScrollable),
      _ => super.getScrollPhysics(context),
    };
  }
}

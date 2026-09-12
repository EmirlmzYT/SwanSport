import 'package:flutter/material.dart';

/// Alt sekmelerde Instagram tarzı anında geçiş.
///
/// Varsayılan platform geçişi (sağdan-sola tek yönlü kayma) yerine yalnızca
/// yumuşak bir belirme/kaybolma kullanır — ölçek/kayma yok, sakin ve nötr.
class SwanPageTransitionsBuilder extends PageTransitionsBuilder {
  const SwanPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Tüm platformlarda aynı anlık geçiş kullanılır. Böylece iOS'taki varsayılan
/// sağdan kayma alt sekmelerde görünmez.
const PageTransitionsTheme kSwanPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: SwanPageTransitionsBuilder(),
    TargetPlatform.iOS: SwanPageTransitionsBuilder(),
    TargetPlatform.macOS: SwanPageTransitionsBuilder(),
    TargetPlatform.windows: SwanPageTransitionsBuilder(),
    TargetPlatform.linux: SwanPageTransitionsBuilder(),
    TargetPlatform.fuchsia: SwanPageTransitionsBuilder(),
  },
);

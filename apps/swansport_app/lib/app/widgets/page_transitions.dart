import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Web'de de fark edilen, kaymasız fade + hafif ölçek geçişi.
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
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: .985, end: 1).animate(curve),
        child: child,
      ),
    );
  }
}

/// Tüm platformlar için geçiş teması.
/// iOS ve macOS'ta yerel Cupertino geçişi (sağdan akıcı kayma, 120Hz ProMotion ve
/// sol kenardan parmakla geri kaydırma / Interactive Pop Gesture) kullanılır.
/// Diğer platformlarda sakin crossfade korunur.
const PageTransitionsTheme kSwanPageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: SwanPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: SwanPageTransitionsBuilder(),
    TargetPlatform.linux: SwanPageTransitionsBuilder(),
    TargetPlatform.fuchsia: SwanPageTransitionsBuilder(),
  },
);

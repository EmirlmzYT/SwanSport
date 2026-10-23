import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'navigation/route_link_adapter.dart';

/// Uygulama dışından gelen olayların (ör. FCM bildirimi) güvenli biçimde
/// rota açabilmesi için tek merkez.
final swanNavigatorKey = GlobalKey<NavigatorState>();
final swanMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Set while the staged GoRouter application is active.
GoRouter? swanGoRouter;

/// Bildirim yükündeki rota geçerli değilse kullanıcıyı bildirim merkezine
/// gönderir. Sunucudan gelen metni doğrudan rota olarak güvenmemek gerekir.
String pushRouteOrNotifications(String? value) {
  if (value == null || !value.startsWith('/')) return '/bildirimler';
  return value;
}

String? swanDeepLinkRoute(Uri uri) {
  return RouteLinkAdapter.fromExternalUri(uri);
}

class SwanDeepLinkObserver extends StatefulWidget {
  const SwanDeepLinkObserver({super.key, required this.child});
  final Widget child;

  @override
  State<SwanDeepLinkObserver> createState() => _SwanDeepLinkObserverState();
}

class _SwanDeepLinkObserverState extends State<SwanDeepLinkObserver> {
  final AppLinks _links = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _lastOpenedRoute;
  DateTime? _lastOpenedAt;

  @override
  void initState() {
    super.initState();
    _subscription = _links.uriLinkStream.listen(_open);
    unawaited(
      _links.getInitialLink().then((uri) {
        if (uri != null) _open(uri);
      }),
    );
  }

  void _open(Uri uri) {
    final route = swanDeepLinkRoute(uri);
    if (route == null) return;
    final now = DateTime.now();
    if (_lastOpenedRoute == route &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastOpenedRoute = route;
    _lastOpenedAt = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = swanGoRouter;
      if (router != null) {
        router.go(route);
      } else {
        swanNavigatorKey.currentState?.pushNamed(route);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

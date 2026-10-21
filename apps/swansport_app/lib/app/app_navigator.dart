import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Uygulama dışından gelen olayların (ör. FCM bildirimi) güvenli biçimde
/// rota açabilmesi için tek merkez.
final swanNavigatorKey = GlobalKey<NavigatorState>();
final swanMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Bildirim yükündeki rota geçerli değilse kullanıcıyı bildirim merkezine
/// gönderir. Sunucudan gelen metni doğrudan rota olarak güvenmemek gerekir.
String pushRouteOrNotifications(String? value) {
  if (value == null || !value.startsWith('/')) return '/bildirimler';
  return value;
}

String? swanDeepLinkRoute(Uri uri) {
  var target = uri;
  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      const {
        'swansport.pages.dev',
        'swansport.com.tr',
        'www.swansport.com.tr',
      }.contains(uri.host)) {
    if (uri.fragment.isEmpty) return null;
    target = Uri.parse(
        uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}');
  } else if (uri.scheme != 'swansport') {
    return null;
  }
  final host = target.scheme == 'swansport'
      ? target.host
      : (target.pathSegments.isEmpty ? null : target.pathSegments.first);
  final parts = target.scheme == 'swansport'
      ? target.pathSegments
      : target.pathSegments.skip(1).toList();
  if (host == 'swan-id' &&
      parts.length == 2 &&
      parts[0] == 'dogrula' &&
      RegExp(r'^[0-9a-fA-F]{48}$').hasMatch(parts[1])) {
    return '/swan-id/dogrula/${parts[1]}';
  }
  if ((host == 'profil' || host == 'kulup-profil') &&
      parts.length == 1 &&
      parts.first.isNotEmpty) {
    return Uri(path: '/$host', queryParameters: {'id': parts.first}).toString();
  }
  if ((host == 'profil' || host == 'kulup-profil') &&
      target.queryParameters['id']?.isNotEmpty == true) {
    return Uri(
      path: '/$host',
      queryParameters: {'id': target.queryParameters['id']!},
    ).toString();
  }
  return null;
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

  @override
  void initState() {
    super.initState();
    _subscription = _links.uriLinkStream.listen(_open);
    unawaited(_links.getInitialLink().then((uri) {
      if (uri != null) _open(uri);
    }));
  }

  void _open(Uri uri) {
    final route = swanDeepLinkRoute(uri);
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      swanNavigatorKey.currentState?.pushNamed(route);
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

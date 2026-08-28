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

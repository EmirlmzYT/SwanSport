import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

class ProPushMessage {
  const ProPushMessage({
    required this.title,
    required this.body,
    this.route,
  });

  final String title;
  final String body;
  final String? route;
}

/// Push client for SwanSport Pro.
///
/// Encapsulates FCM initialization, permission requests, token registration,
/// and refresh listeners targeting [PushAppTarget.pro].
///
/// Gracefully handles preview builds, web environments, and missing configuration
/// without throwing unhandled exceptions.
class ProPushClient {
  ProPushClient({
    PushSubscriptionService? subscriptionService,
  }) : _subscriptionService = subscriptionService;

  final PushSubscriptionService? _subscriptionService;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;
  String? _lastToken;

  /// Whether the current platform supports native Firebase push delivery.
  bool get isSupported {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) return true;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const bool.fromEnvironment(
        'IOS_FIREBASE_ENABLED',
        defaultValue: false,
      );
    }
    return false;
  }

  /// Ensures Firebase core is safely initialized for FCM.
  /// Returns false if not supported or missing config files.
  Future<bool> initialize() async {
    if (_initialized) return true;
    if (!isSupported) return false;

    try {
      await Firebase.initializeApp();
      _initialized = true;
      return true;
    } catch (e) {
      debugPrint('ProPushClient: Firebase init skipped or failed: $e');
      return false;
    }
  }

  /// Retrieves the device token if available.
  Future<String?> getDeviceToken() async {
    if (!await initialize()) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final apns = await messaging.getAPNSToken();
        if (apns == null) return null;
      }
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _lastToken = token;
        return token;
      }
    } catch (e) {
      debugPrint('ProPushClient: getDeviceToken error: $e');
    }
    return null;
  }

  /// Requests user notification permissions.
  Future<bool> requestPermission() async {
    if (!await initialize()) return false;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('ProPushClient: requestPermission error: $e');
      return false;
    }
  }

  /// Registers this device token with Supabase using [PushAppTarget.pro].
  Future<void> registerWithServer([PushSubscriptionService? service]) async {
    final activeService = service ?? _subscriptionService;
    if (activeService == null) return;
    final token = await getDeviceToken();
    if (token == null || token.isEmpty) return;

    try {
      await activeService.registerSubscription(
        endpoint: token,
        kind: 'fcm',
      );
      _listenTokenRefresh(activeService);
    } catch (e) {
      debugPrint('ProPushClient: server registration failed: $e');
    }
  }

  /// Removes device token registration from Supabase.
  Future<void> unregisterFromServer([PushSubscriptionService? service]) async {
    final activeService = service ?? _subscriptionService;
    // Registration always caches the active token. Do not initialize Firebase
    // or request a fresh token while the user is trying to sign out.
    final token = _lastToken;
    Object? serverError;
    try {
      if (activeService != null && token != null && token.isNotEmpty) {
        await activeService.unregisterSubscription(token);
      }
    } catch (e) {
      debugPrint('ProPushClient: server unregistration failed: $e');
      serverError = e;
    } finally {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      if (_initialized) {
        try {
          await FirebaseMessaging.instance.deleteToken();
        } catch (e) {
          debugPrint('ProPushClient: local token deletion failed: $e');
        }
      }
      _lastToken = null;
    }
    if (serverError != null) throw serverError;
  }

  ProPushMessage _message(RemoteMessage value) {
    final rawRoute = value.data['url'];
    return ProPushMessage(
      title: value.notification?.title ?? 'SwanSport Pro',
      body: value.notification?.body ?? '',
      route: rawRoute is String ? rawRoute : null,
    );
  }

  Stream<ProPushMessage> foregroundMessages() async* {
    if (!await initialize()) return;
    yield* FirebaseMessaging.onMessage.map(_message);
  }

  Stream<ProPushMessage> openedMessages() async* {
    if (!await initialize()) return;
    yield* FirebaseMessaging.onMessageOpenedApp.map(_message);
  }

  Future<ProPushMessage?> initialMessage() async {
    if (!await initialize()) return null;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return message == null ? null : _message(message);
  }

  void _listenTokenRefresh(PushSubscriptionService service) {
    _tokenRefreshSub?.cancel();
    try {
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          _lastToken = newToken;
          try {
            await service.registerSubscription(
              endpoint: newToken,
              kind: 'fcm',
            );
          } catch (e) {
            debugPrint('ProPushClient: token refresh registration failed: $e');
          }
        },
        onError: (Object e) {
          debugPrint('ProPushClient: token refresh error: $e');
        },
      );
    } catch (e) {
      debugPrint('ProPushClient: onTokenRefresh listen error: $e');
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}

/// Provider for [ProPushClient] bound to [pushSubscriptionServiceProvider].
final proPushClientProvider = Provider<ProPushClient>((ref) {
  final service = ref.watch(pushSubscriptionServiceProvider);
  final client = ProPushClient(subscriptionService: service);
  ref.onDispose(client.dispose);
  return client;
});

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push.dart';
import 'push_token_gate.dart';

/// Android/iOS bildirim taşıyıcısı — Firebase Cloud Messaging.
///
/// Tarayıcı sürümünden farkı yalnızca taşıyıcı: orada abonelik üç parçalıydı
/// (adres + iki anahtar) ve yükü biz şifreliyorduk, burada tek bir cihaz
/// token'ı var ve şifrelemeyi Google yapıyor. Kayıt, tazeleme ve silme akışı
/// aynı arayüzün arkasında duruyor.
///
/// iOS için geçerli APNs imzası/capability ve Firebase APNs anahtarı gerekir.

/// Firebase yalnızca bir kez başlatılabilir; ikinci çağrı hata verir.
bool _initialized = false;
Future<void>? _initializing;

Future<void> _ensureInitialized() async {
  if (_initialized) return;
  final work=_initializing??=_initializeNative();
  try{await work;}finally{if(identical(_initializing,work))_initializing=null;}
}

Future<void> _initializeNative() async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }
    _initialized = true;
  } catch (error) {
    debugPrint('SwanSport: native push initialization skipped or failed: $error');
    lastPushError = '$error';
    _initialized = false;
  }
}

bool get pushSupported => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

Future<String?> _fcmToken(FirebaseMessaging messaging) async {
  if(defaultTargetPlatform==TargetPlatform.iOS){
    final apns=await waitForApnsToken(read:messaging.getAPNSToken);
    if(apns==null)throw const PushException(PushFailure.apnsUnavailable);
  }
  return messaging.getToken();
}

/// İzin daha önce verilmiş mi?
///
/// Senkron okunması gereken bir değer ama Firebase'in izin sorgusu asenkron;
/// bu yüzden son bilinen durum tutuluyor. İlk çağrıda `false` döner, ilk
/// [pushCurrent] veya [pushSubscribe] çağrısından sonra doğrulanır.
bool _permissionGranted = false;
bool get pushPermissionGranted => _permissionGranted;

/// İzin ister ve cihaz token'ını döner.
Future<PushSub> pushSubscribe() async {
  if (!pushSupported) {
    throw const PushException(PushFailure.unsupported);
  }
  await _ensureInitialized();

  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(alert:true,badge:true,sound:true,provisional:false);

  final granted =
      settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
  _permissionGranted = granted;

  if (!granted) {
    throw const PushException(PushFailure.denied);
  }

  final token = await _fcmToken(messaging);
  if (token == null || token.isEmpty) {
    // İzin var ama token yok: genellikle Google Play Services eksik ya da
    // cihazın ağı FCM'e ulaşamıyor.
    throw const PushException(PushFailure.failed);
  }
  return PushSub.fcm(token);
}

/// Var olan token'ı döner; izin yoksa null.
///
/// İzin **istemez** — sessiz tazeleme bunu kullanıyor ve kullanıcıya
/// sormadan yeni bir izin penceresi açmamalı.
Future<PushSub?> pushCurrent() async {
  if (!pushSupported) return null;
  await _ensureInitialized();

  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.getNotificationSettings();
  final granted =
      settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
  _permissionGranted = granted;
  if (!granted) return null;

  final token = await _fcmToken(messaging);
  if (token == null || token.isEmpty) return null;
  return PushSub.fcm(token);
}

/// Token'ı geçersiz kılar ve silinen adresi döner.
Future<String?> pushUnsubscribe() async {
  if (!pushSupported) return null;
  await _ensureInitialized();

  final messaging = FirebaseMessaging.instance;
  final token = await _fcmToken(messaging);
  if (token == null) return null;

  // Token'ı sunucu tarafında da silebilmek için önce değerini alıp sonra
  // iptal ediyoruz; ters sırada silinecek adresi kaybederdik.
  await messaging.deleteToken();
  _permissionGranted = false;
  return token;
}

/// FCM token'ı Google tarafından kendiliğinden yenilenebilir.
///
/// Yenilendiğinde eski token ölür; dinlemezsek kullanıcı bir gün sessizce
/// bildirim almaz hale gelir. Uygulama açılışında bir kez bağlanır.
Stream<String> pushTokenChanges() async* {
  if (!pushSupported) return;
  await _ensureInitialized();
  yield* FirebaseMessaging.instance.onTokenRefresh;
}

PushMessage _message(RemoteMessage value) => PushMessage(
      title: value.notification?.title ?? 'SwanSport',
      body: value.notification?.body ?? '',
      route: value.data['url'] as String?,
    );

/// Uygulama ön plandayken Android sistem bildirimi göstermediği için bu akış
/// uygulamanın kendi görünür uyarısını besler.
Stream<PushMessage> pushForegroundMessages() async* {
  if (!pushSupported) return;
  await _ensureInitialized();
  yield* FirebaseMessaging.onMessage.map(_message);
}

/// Arka plandaki bildirime dokunulduğunda Flutter'a gelen olay.
Stream<PushMessage> pushOpenedMessages() async* {
  if (!pushSupported) return;
  await _ensureInitialized();
  yield* FirebaseMessaging.onMessageOpenedApp.map(_message);
}

/// Uygulama tamamen kapalıyken bildirime dokunularak açılmışsa ilk mesaj.
Future<PushMessage?> pushInitialMessage() async {
  if (!pushSupported) return null;
  await _ensureInitialized();
  final message = await FirebaseMessaging.instance.getInitialMessage();
  return message == null ? null : _message(message);
}

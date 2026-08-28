import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push.dart';

/// Web dışı platformlarda (Android) bildirim — Firebase Cloud Messaging.
///
/// Tarayıcı sürümünden farkı yalnızca taşıyıcı: orada abonelik üç parçalıydı
/// (adres + iki anahtar) ve yükü biz şifreliyorduk, burada tek bir cihaz
/// token'ı var ve şifrelemeyi Google yapıyor. Kayıt, tazeleme ve silme akışı
/// aynı arayüzün arkasında duruyor.
///
/// iOS bu dosyayı da kullanır ama APNs anahtarı Firebase'e tanımlanmadan
/// çalışmaz; şu an yalnızca Android hedefleniyor.

/// Firebase yalnızca bir kez başlatılabilir; ikinci çağrı hata verir.
bool _initialized = false;

Future<void> _ensureInitialized() async {
  if (_initialized) return;
  // Yapılandırma android/app/google-services.json dosyasından okunuyor;
  // Dart tarafında anahtar tutulmuyor.
  await Firebase.initializeApp();
  _initialized = true;
}

/// Android'de bildirim kurulabilir.
bool get pushSupported => defaultTargetPlatform == TargetPlatform.android;

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
  final settings = await messaging.requestPermission();

  final granted =
      settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
  _permissionGranted = granted;

  if (!granted) {
    throw const PushException(PushFailure.denied);
  }

  final token = await messaging.getToken();
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

  final token = await messaging.getToken();
  if (token == null || token.isEmpty) return null;
  return PushSub.fcm(token);
}

/// Token'ı geçersiz kılar ve silinen adresi döner.
Future<String?> pushUnsubscribe() async {
  if (!pushSupported) return null;
  await _ensureInitialized();

  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();
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
Stream<String> pushTokenChanges() {
  if (!pushSupported) return const Stream<String>.empty();
  return FirebaseMessaging.instance.onTokenRefresh;
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

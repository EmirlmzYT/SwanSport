import 'push_io.dart' if (dart.library.js_interop) 'push_web.dart' as impl;

/// Bir cihazın push aboneliği.
///
/// İki taşıyıcıyı birden temsil eder ve alanların anlamı taşıyıcıya göre
/// değişir:
///
/// * **web** — [endpoint] tarayıcının verdiği push servisi adresi;
///   [p256dh] ve [auth] yükü şifrelemek için gerekli, ikisi de dolu olur.
/// * **fcm** — [endpoint] Android cihazının FCM token'ı; şifrelemeyi Google
///   yaptığı için [p256dh] ve [auth] null'dur.
///
/// Tek sınıf tutuluyor çünkü kayıt, tazeleme ve silme akışları ikisinde de
/// aynı; yalnızca gönderim yolu ayrışıyor ve o da sunucuda seçiliyor.
class PushSub {
  const PushSub({
    required this.endpoint,
    required this.kind,
    this.p256dh,
    this.auth,
  });

  /// Tarayıcı aboneliği — üç alan da zorunlu.
  const PushSub.web({
    required this.endpoint,
    required String this.p256dh,
    required String this.auth,
  }) : kind = 'web';

  /// Android cihaz token'ı.
  const PushSub.fcm(this.endpoint)
      : kind = 'fcm',
        p256dh = null,
        auth = null;

  final String endpoint;

  /// `web` | `fcm` — veritabanındaki `push_subscriptions.kind` ile aynı.
  final String kind;

  final String? p256dh;
  final String? auth;
}

/// Taşıyıcıdan bağımsız bildirim içeriği.
class PushMessage {
  const PushMessage({
    required this.title,
    required this.body,
    this.route,
  });

  final String title;
  final String body;
  final String? route;
}

/// Push aboneliğinin alınamama nedeni — kullanıcıya doğru cümleyi kurmak için.
enum PushFailure {
  /// Platform push desteklemiyor (ör. iOS'ta ana ekrana eklenmemiş Safari).
  unsupported,

  /// Kullanıcı bildirim iznini reddetti.
  denied,

  /// Tarayıcı abonelik üretemedi.
  failed,
}

class PushException implements Exception {
  const PushException(this.reason);
  final PushFailure reason;
}

/// Bu platformda push bildirimi kurulabilir mi?
bool get pushSupported => impl.pushSupported;

/// Kullanıcı daha önce izin verdi mi? (izin istemez, yalnızca okur)
bool get pushPermissionGranted => impl.pushPermissionGranted;

/// İzin ister ve abonelik üretir. Başarısızlıkta [PushException] fırlatır.
Future<PushSub> pushSubscribe() => impl.pushSubscribe();

/// Var olan aboneliği döner (izin verilmişse), yoksa null.
Future<PushSub?> pushCurrent() => impl.pushCurrent();

/// Aboneliği cihaz tarafında iptal eder; iptal edilen adresi döner.
Future<String?> pushUnsubscribe() => impl.pushUnsubscribe();

/// Cihaz adresinin kendiliğinden değiştiği anlar.
///
/// Android'de FCM token'ı Google tarafından yenilenebiliyor; dinlemezsek eski
/// token ölür ve kullanıcı sessizce bildirim almaz hale gelir. Web'de karşılığı
/// yok, boş akış döner.
Stream<String> pushTokenChanges() => impl.pushTokenChanges();

/// Uygulama açıkken gelen bildirimler.
Stream<PushMessage> pushForegroundMessages() => impl.pushForegroundMessages();

/// Kullanıcının dokunduğu arka plan bildirimleri.
Stream<PushMessage> pushOpenedMessages() => impl.pushOpenedMessages();

/// Uygulamayı kapalıyken açan bildirimi döner.
Future<PushMessage?> pushInitialMessage() => impl.pushInitialMessage();

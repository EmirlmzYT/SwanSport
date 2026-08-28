import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'push.dart';

/// Sunucunun VAPID açık anahtarı. Gizli değildir — eşi olan özel anahtar
/// yalnızca Cloudflare tarafındaki gönderici fonksiyonda durur.
const String kVapidPublicKey =
    'BBxsAvk_FAIbgiNdf0RiBx8DqxChwCwfiTloObmmNbAnMy8xM8KdChew3_mKnbFPX_4YkIHj4WYnNXTWyYvPj70';

/// Flutter'ın kendi service worker'ıyla çakışmasın diye ayrı kapsam.
const String _swPath = '/push-sw/sw.js';

/// Tipli bağlama yerine dinamik erişim kullanılıyor: push API'leri tarayıcıdan
/// tarayıcıya eksik olabiliyor, `has` ile yoklamak derleme zamanı bağımlılığı
/// olmadan güvenli davranmayı sağlıyor.
JSAny? _get(JSObject on, String name) {
  if (!on.has(name)) return null;
  final v = on.getProperty<JSAny?>(name.toJS);
  return v.isUndefinedOrNull ? null : v;
}

/// Nesne bekleyen yerler için — değer nesne değilse null.
JSObject? _obj(JSObject on, String name) => _get(on, name) as JSObject?;

JSObject? get _navigator => _obj(globalContext, 'navigator');
JSObject? get _serviceWorker {
  final n = _navigator;
  return n == null ? null : _obj(n, 'serviceWorker');
}

bool get pushSupported =>
    _serviceWorker != null &&
    globalContext.has('PushManager') &&
    globalContext.has('Notification');

String get _permission {
  final n = _obj(globalContext, 'Notification');
  if (n == null || !n.has('permission')) return 'default';
  return (n.getProperty('permission'.toJS) as JSString).toDart;
}

bool get pushPermissionGranted => _permission == 'granted';

/// Service worker'ı kaydeder ve etkinleşmesini bekler.
///
/// Yeni kaydedilen worker bir an "installing" durumunda kalır; bu sırada
/// `subscribe` çağırmak bazı tarayıcılarda hata veriyor, o yüzden kısa bir
/// yoklama ile aktifleşmesi beklenir.
Future<JSObject?> _registration() async {
  final sw = _serviceWorker;
  if (sw == null) return null;

  final reg = await (sw.callMethod<JSPromise<JSObject>>(
          'register'.toJS, _swPath.toJS, _scopeOptions()))
      .toDart;

  for (var i = 0; i < 40; i++) {
    if (_get(reg, 'active') != null) return reg;
    await Future<void>.delayed(const Duration(milliseconds: 125));
  }
  return reg; // yine de dene — bazı tarayıcılarda active geç doluyor
}

JSObject _scopeOptions() {
  final o = JSObject();
  o.setProperty('scope'.toJS, '/push-sw/'.toJS);
  return o;
}

PushSub? _toSub(JSObject? subscription) {
  if (subscription == null) return null;
  final json = subscription.callMethod<JSObject>('toJSON'.toJS);
  final keys = _obj(json, 'keys');
  if (keys == null) return null;

  final endpoint = _get(json, 'endpoint');
  if (endpoint == null) return null;

  return PushSub.web(
    endpoint: (endpoint as JSString).toDart,
    p256dh: (keys.getProperty('p256dh'.toJS) as JSString).toDart,
    auth: (keys.getProperty('auth'.toJS) as JSString).toDart,
  );
}

Future<PushSub> pushSubscribe() async {
  if (!pushSupported) throw const PushException(PushFailure.unsupported);

  // İzin: daha önce reddedilmişse tarayıcı yeniden sormaz, doğrudan bildir.
  if (_permission != 'granted') {
    final notif = _obj(globalContext, 'Notification')!;
    final result =
        await (notif.callMethod<JSPromise<JSString>>('requestPermission'.toJS))
            .toDart;
    if (result.toDart != 'granted') {
      throw const PushException(PushFailure.denied);
    }
  }

  final reg = await _registration();
  if (reg == null) throw const PushException(PushFailure.unsupported);

  final pm = _obj(reg, 'pushManager');
  if (pm == null) throw const PushException(PushFailure.unsupported);

  // Zaten abonelik varsa yenisini üretme — endpoint sabit kalsın.
  final existing =
      await (pm.callMethod<JSPromise<JSObject?>>('getSubscription'.toJS)).toDart;
  final current = _toSub(existing);
  if (current != null) return current;

  final opts = JSObject();
  opts.setProperty('userVisibleOnly'.toJS, true.toJS);
  opts.setProperty('applicationServerKey'.toJS, kVapidPublicKey.toJS);

  try {
    final sub =
        await (pm.callMethod<JSPromise<JSObject>>('subscribe'.toJS, opts))
            .toDart;
    final made = _toSub(sub);
    if (made == null) throw const PushException(PushFailure.failed);
    return made;
  } on PushException {
    rethrow;
  } catch (_) {
    throw const PushException(PushFailure.failed);
  }
}

Future<PushSub?> pushCurrent() async {
  if (!pushSupported || !pushPermissionGranted) return null;
  try {
    final reg = await _registration();
    final pm = reg == null ? null : _obj(reg, 'pushManager');
    if (pm == null) return null;
    final existing =
        await (pm.callMethod<JSPromise<JSObject?>>('getSubscription'.toJS))
            .toDart;
    return _toSub(existing);
  } catch (_) {
    return null;
  }
}

Future<String?> pushUnsubscribe() async {
  try {
    final reg = await _registration();
    final pm = reg == null ? null : _obj(reg, 'pushManager');
    if (pm == null) return null;

    final existing =
        await (pm.callMethod<JSPromise<JSObject?>>('getSubscription'.toJS))
            .toDart;
    if (existing == null) return null;

    final sub = _toSub(existing);
    await (existing.callMethod<JSPromise<JSBoolean>>('unsubscribe'.toJS)).toDart;
    return sub?.endpoint;
  } catch (_) {
    return null;
  }
}

/// Web'de token yenileme kavramı yok — abonelik adresi değişirse
/// `pushCurrent` zaten yenisini döner. Arayüz bütünlüğü için boş akış.
Stream<String> pushTokenChanges() => const Stream<String>.empty();

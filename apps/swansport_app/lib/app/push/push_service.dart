import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../app_navigator.dart';
import 'push.dart';

/// ---------------------------------------------------------------------------
/// Push aboneliğinin veritabanı tarafı.
///
/// Tarayıcıdan alınan abonelik `push_subscriptions` tablosuna yazılır; yeni bir
/// bildirim oluştuğunda veritabanı tetikleyicisi bu satırları okuyup gönderim
/// servisine iletir.
/// ---------------------------------------------------------------------------

class PushService {
  PushService(this._c);
  final SupabaseClient _c;

  /// Cihazı kaydeder. Aynı adres tekrar gelirse satır güncellenir.
  Future<void> register(PushSub sub, {String? userAgent}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    await _c.from('push_subscriptions').upsert({
      'profile_id': uid,
      'endpoint': sub.endpoint,
      // Taşıyıcı: sunucu hangi yolla göndereceğini buna bakarak seçiyor.
      'kind': sub.kind,
      // FCM'de bu ikisi null; şifrelemeyi Google yapıyor.
      'p256dh': sub.p256dh,
      'auth': sub.auth,
      if (userAgent != null) 'user_agent': userAgent,
    }, onConflict: 'endpoint');
  }

  Future<void> unregister(String endpoint) async {
    await _c
        .rpc<void>('drop_push_subscription', params: {'p_endpoint': endpoint});
  }

  /// Bu cihazın adresi kayıtlı mı?
  Future<bool> isRegistered(String endpoint) async {
    final rows = await _c
        .from('push_subscriptions')
        .select('id')
        .eq('endpoint', endpoint)
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.watch(supabaseClientProvider));
});

/// Bu cihazda bildirimler açık mı? (hem tarayıcı izni hem veritabanı kaydı)
final pushEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!pushSupported || !ref.watch(isSupabaseEnabledProvider)) return false;
  final sub = await pushCurrent();
  if (sub == null) return false;
  return ref.watch(pushServiceProvider).isRegistered(sub.endpoint);
});

/// Bildirimleri açar. Hata durumunda [PushException] fırlatır.
Future<void> enablePush(WidgetRef ref) async {
  final sub = await pushSubscribe();
  await ref.read(pushServiceProvider).register(sub);
  ref.invalidate(pushEnabledProvider);
}

/// Bildirimleri kapatır — hem tarayıcı aboneliği hem kayıt silinir.
Future<void> disablePush(WidgetRef ref) async {
  final endpoint = await pushUnsubscribe();
  if (endpoint != null) {
    await ref.read(pushServiceProvider).unregister(endpoint);
  }
  ref.invalidate(pushEnabledProvider);
}

/// Giriş yapılmış ve izin önceden verilmişse aboneliği sessizce tazeler.
///
/// Push adresleri tarayıcı tarafından kendiliğinden değişebiliyor; bu çağrı
/// olmadan kullanıcı bir gün sessizce bildirim almaz hale gelir.
Future<void> refreshPushSilently(WidgetRef ref) async {
  if (!pushSupported) return;
  try {
    // Android'de izin durumu ancak Firebase'e sorulduktan sonra biliniyor;
    // `pushCurrent` izin istemeden sorar, izin yoksa null döner. Bu yüzden
    // `pushPermissionGranted` ön kontrolü burada yapılamaz — yapılsaydı
    // uygulama her açılışta izinsiz sayılıp abonelik hiç tazelenmezdi.
    final sub = await pushCurrent();
    if (sub == null) return;
    await ref.read(pushServiceProvider).register(sub);
  } catch (error) {
    // Sessiz tazeleme başarısız olursa kullanıcıyı rahatsız etme; ama izsiz
    // kalmasın — bildirimlerin neden gelmediği ancak buradan anlaşılır.
    debugPrint('SwanSport: push tazeleme başarısız — $error');
  }
}

/// FCM token'ı yenilendiğinde yeni adresi kaydeder.
///
/// Google token'ı kendiliğinden döndürebiliyor (uygulama güncellemesi, veri
/// temizliği, uzun süre kullanılmama). Dinlenmezse eski token ölür ve
/// kullanıcı sessizce bildirim almaz hale gelir — en sinsi bildirim hatası
/// budur, çünkü hiçbir yerde hata görünmez.
///
/// Uygulama ömrü boyunca dinlenir; abonelik iptal edilmez.
///
/// Birden fazla kez çağrılması zararsız — ana ekran her açıldığında
/// çağrıldığı için tekrar tekrar dinleyici eklememesi gerekiyor.
StreamSubscription<String>? _tokenSub;

void listenPushTokenChanges(WidgetRef ref) {
  if (_tokenSub != null) return;
  _tokenSub = pushTokenChanges().listen((token) {
    unawaited(
      ref.read(pushServiceProvider).register(PushSub.fcm(token)).catchError(
            (Object e) =>
                debugPrint('SwanSport: yeni push token kaydedilemedi — $e'),
          ),
    );
  });
}

/// Push yaşam döngüsünü ekrandan bağımsız olarak uygulama ömrüne bağlar.
/// Böylece kullanıcı akış ekranını hiç açmasa bile token yenilenir ve bildirime
/// dokununca hedef rota açılır.
class PushLifecycleObserver extends ConsumerStatefulWidget {
  const PushLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushLifecycleObserver> createState() =>
      _PushLifecycleObserverState();
}

class _PushLifecycleObserverState extends ConsumerState<PushLifecycleObserver> {
  StreamSubscription<PushMessage>? _foregroundSub;
  StreamSubscription<PushMessage>? _openedSub;

  @override
  void initState() {
    super.initState();
    listenPushTokenChanges(ref);
    _foregroundSub = pushForegroundMessages().listen(_showForegroundMessage);
    _openedSub = pushOpenedMessages().listen(_openMessage);
    Future.microtask(() async {
      await refreshPushSilently(ref);
      final initial = await pushInitialMessage();
      if (initial != null) _openMessage(initial);
    });
  }

  void _showForegroundMessage(PushMessage message) {
    swanMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message.body.isEmpty
            ? message.title
            : '${message.title}: ${message.body}'),
        action: SnackBarAction(
          label: 'Aç',
          onPressed: () => _openMessage(message),
        ),
      ),
    );
  }

  void _openMessage(PushMessage message) {
    final navigator = swanNavigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openMessage(message));
      return;
    }
    navigator.pushNamed(pushRouteOrNotifications(message.route));
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

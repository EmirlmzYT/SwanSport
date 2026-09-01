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

/// Cihaz adresinin sunucudaki durumu.
enum PushSubState {
  /// Bu hesaba kayıtlı — beklenen hâl.
  mine,

  /// Kayıtlı ama **başka bir hesaba**. Aynı telefonda hesap değiştirilince
  /// oluşuyor ve eski kodda `42501`'in sebebiydi.
  otherAccount,

  /// Hiç kaydedilmemiş.
  missing,

  /// Oturum yok.
  noSession,
}

/// Sessiz tazelemede son yaşanan hata.
///
/// **Neden tutuluyor:** `refreshPushSilently` hatayı yalnızca `debugPrint`
/// ediyordu ve release APK'da o çıktı hiçbir yere gitmiyor. Sonuç: cihaz
/// kaydedilemiyor, kullanıcı "kayıt yok" görüyor, sebebini kimse
/// öğrenemiyor. Fonksiyonun kendi yorumu bunu zaten "en sinsi bildirim
/// hatası" diye tarif ediyordu.
///
/// Tanılama paneli bunu gösteriyor.
String? lastPushError;

class PushService {
  PushService(this._c);
  final SupabaseClient _c;

  /// Cihazı kaydeder. Aynı adres tekrar gelirse satır güncellenir.
  ///
  /// **RPC üzerinden, doğrudan `upsert` ile değil.** Doğrudan upsert
  /// `42501` veriyordu: `endpoint` globalde tekil ve RLS politikası
  /// `using (profile_id = auth.uid())`. Postgres `ON CONFLICT DO UPDATE`'te
  /// `USING`'i **mevcut satıra** uyguluyor, yani cihaz daha önce başka bir
  /// hesapla kaydedildiyse yeni hesap o satıra dokunamıyordu. Aynı telefonda
  /// iki hesapla giriş yapmak bunu tetiklemeye yetiyor ve sonuç: bildirim
  /// aç/kapa çalışmıyor, cihaz hiç kaydedilmiyor, bildirim hiç gelmiyor.
  ///
  /// `register_push_subscription` (0043) `security definer` ve adresi o an
  /// giriş yapmış kişiye devrediyor — FCM token'ı kullanıcıya değil uygulama
  /// kurulumuna ait, telefonda hesap değişince bildirimler de değişmeli.
  Future<void> register(PushSub sub, {String? userAgent}) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _c.rpc<void>('register_push_subscription', params: {
        'p_endpoint': sub.endpoint,
        'p_kind': sub.kind,
        'p_p256dh': sub.p256dh,
        'p_auth': sub.auth,
        'p_user_agent': userAgent,
      });
    } on PostgrestException catch (e) {
      // 0043 henüz çalıştırılmadıysa fonksiyon yok (PGRST202). Eski yola
      // düş: kendi cihazını ilk kez kaydeden kullanıcı için o da çalışıyor,
      // yalnızca hesap değişimi senaryosunda 42501 veriyor.
      if (e.code != 'PGRST202') rethrow;
      await _c.from('push_subscriptions').upsert({
        'profile_id': uid,
        'endpoint': sub.endpoint,
        'kind': sub.kind,
        'p256dh': sub.p256dh,
        'auth': sub.auth,
        if (userAgent != null) 'user_agent': userAgent,
      }, onConflict: 'endpoint');
    }
  }

  Future<void> unregister(String endpoint) async {
    await _c
        .rpc<void>('drop_push_subscription', params: {'p_endpoint': endpoint});
  }

  /// Bu cihazın adresi kayıtlı mı?
  Future<bool> isRegistered(String endpoint) async =>
      await subscriptionState(endpoint) == PushSubState.mine;

  /// Cihaz adresinin sunucudaki durumu.
  ///
  /// Düz `select` yetmiyor: RLS başkasına ait satırı **boş** döndürüyor ve
  /// tanılama bunu "kayıt yok" diye gösteriyordu — oysa satır vardı, başka
  /// hesabındı. Yanlış teşhis, yanlış çözüme götürüyor.
  Future<PushSubState> subscriptionState(String endpoint) async {
    try {
      final v = await _c.rpc<dynamic>('push_subscription_state',
          params: {'p_endpoint': endpoint});
      return switch ('$v') {
        'mine' => PushSubState.mine,
        'other_account' => PushSubState.otherAccount,
        'no_session' => PushSubState.noSession,
        _ => PushSubState.missing,
      };
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      // 0043 yoksa eski yolla bak — "başka hesapta" ayrımını yapamıyor.
      final rows = await _c
          .from('push_subscriptions')
          .select('id')
          .eq('endpoint', endpoint)
          .limit(1);
      return (rows as List).isNotEmpty
          ? PushSubState.mine
          : PushSubState.missing;
    }
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

/// Şu an açık olan sohbetin karşı tarafı.
///
/// **Neden düz bir değişken, sağlayıcı değil:** bunu okuyan yer bir widget
/// değil, uygulama ömrü boyunca yaşayan push dinleyicisi. Riverpod'a taşımak
/// yalnızca yaşam döngüsü karmaşası ekler; burada tutulan şey tek bir geçici
/// UI durumu.
///
/// [ChatScreen] açılırken doldurur, kapanırken temizler.
class OpenChat {
  OpenChat._();

  static String? peerId;
  static String? peerName;

  static void open(String id, String name) {
    peerId = id;
    peerName = name;
  }

  static void close(String id) {
    // Kimlik kontrolü şart: iki sohbet arasında geçerken yeni ekranın
    // `initState`'i eskisinin `dispose`'undan **önce** çalışıyor. Kontrolsüz
    // temizlemek yeni açılan sohbeti kapalı sayardı.
    if (peerId == id) {
      peerId = null;
      peerName = null;
    }
  }

  /// Bu bildirim, şu an ekranda açık olan sohbetten mi geliyor?
  ///
  /// Push yükü gönderenin kimliğini taşımıyor, yalnızca başlığı:
  /// `"<Ad> size yazdı"` (0040'taki `notify_direct_message`). Bu yüzden
  /// eşleştirme **ada** göre yapılıyor.
  ///
  /// Kasıtlı olarak temkinli: ad tutmazsa bildirim **gösteriliyor**. Yanlışlıkla
  /// göstermek, yanlışlıkla gizlemekten iyi — gizlenen mesajı kullanıcı hiç
  /// öğrenemez.
  static bool matches(String title) {
    final name = peerName?.trim();
    if (name == null || name.isEmpty) return false;
    return title.trim().toLowerCase().startsWith(name.toLowerCase());
  }
}

/// Bildirim zincirinin çalışma anındaki durumu.
///
/// **Neden var:** APK'da bildirimlerin hiç gelmediği bildirildi ve statik
/// denetimde bir eksik bulunamadı — `google-services.json`, izin, kanal,
/// sunucu yükü hepsi doğruydu. Hata çalışma anında ve elle bakmadan
/// görünmüyor. Bu ekran kopmanın **hangi halkada** olduğunu söylüyor:
/// izin mi verilmemiş, token mı alınamıyor, sunucuya mı kaydedilmemiş.
class PushDiagnostics {
  const PushDiagnostics({
    required this.supported,
    required this.permission,
    required this.token,
    required this.state,
    this.error,
  });

  final bool supported;
  final bool permission;
  final String? token;
  final PushSubState state;
  final String? error;

  bool get registered => state == PushSubState.mine;

  bool get healthy =>
      supported && permission && token != null && registered && error == null;

  /// Kopmanın ilk halkası — kullanıcıya tek cümlede ne yapacağını söyler.
  String get summary {
    if (!supported) return 'Bu platformda bildirim desteklenmiyor.';
    if (error != null) return 'Kontrol sırasında hata: $error';
    if (!permission) {
      return 'İzin verilmemiş. Telefon Ayarlar > Uygulamalar > SwanSport > '
          'Bildirimler bölümünden izin ver, sonra anahtarı aç.';
    }
    if (token == null) {
      return 'İzin var ama cihaz adresi alınamıyor. Genellikle Google Play '
          'Servisleri eksik ya da ağ FCM\'e ulaşamıyor.';
    }
    if (state == PushSubState.otherAccount) {
      // 0043 öncesinin asıl hatası. `endpoint` globalde tekil ve RLS
      // politikası mevcut satıra bakıyor; başka hesabın satırına dokunmaya
      // çalışan insert `42501` ile düşüyordu.
      return 'Bu cihaz başka bir hesaba kayıtlı — aynı telefonda başka bir '
          'hesapla giriş yapılmış. Anahtarı kapatıp tekrar aç; cihaz bu '
          'hesaba devredilecek. Hata sürerse 0043 migration çalıştırılmamış '
          'demektir.';
    }
    if (!registered) {
      return 'Cihaz adresi var ama sunucuya kaydedilmemiş. Anahtarı kapatıp '
          'tekrar aç.';
    }
    return 'Bildirim zinciri kurulu. Gelmiyorsa sorun gönderim tarafında.';
  }
}

/// Zinciri baştan sona yoklar.
final pushDiagnosticsProvider =
    FutureProvider.autoDispose<PushDiagnostics>((ref) async {
  if (!pushSupported) {
    return const PushDiagnostics(
      supported: false,
      permission: false,
      token: null,
      state: PushSubState.missing,
    );
  }
  try {
    final sub = await pushCurrent();
    final state = sub == null
        ? PushSubState.missing
        : await ref.read(pushServiceProvider).subscriptionState(sub.endpoint);
    return PushDiagnostics(
      supported: true,
      permission: pushPermissionGranted,
      token: sub?.endpoint,
      state: state,
      // Kayıt yoksa sebebi genelde sessiz tazelemede yaşanmış oluyor.
      error: state == PushSubState.mine ? null : lastPushError,
    );
  } catch (e) {
    return PushDiagnostics(
      supported: true,
      permission: pushPermissionGranted,
      token: null,
      state: PushSubState.missing,
      error: '$e',
    );
  }
});

/// Bildirimleri açar. Hata durumunda [PushException] fırlatır.
Future<void> enablePush(WidgetRef ref) async {
  final sub = await pushSubscribe();
  await ref.read(pushServiceProvider).register(sub);
  lastPushError = null;
  ref.invalidate(pushEnabledProvider);
  ref.invalidate(pushDiagnosticsProvider);
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
    // `debugPrint` release'de görünmüyor, o yüzden ayrıca saklıyoruz.
    lastPushError = '$error';
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
  try {
    _tokenSub = pushTokenChanges().listen(
      (token) {
        unawaited(
          ref.read(pushServiceProvider).register(PushSub.fcm(token)).catchError(
                (Object e) =>
                    debugPrint('SwanSport: yeni push token kaydedilemedi — $e'),
              ),
        );
      },
      onError: (Object error, StackTrace stackTrace) => debugPrint(
          'SwanSport: push token dinleyicisi başlatılamadı — $error'),
    );
  } catch (error) {
    debugPrint('SwanSport: push token dinleyicisi başlatılamadı — $error');
  }
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
    // Zaten o sohbetin içindeysen uyarı gösterme: mesaj sohbete canlı
    // düşüyor, üstüne bir de ekranın altından şerit çıkması gürültü.
    //
    // Yalnızca **o kişiden** gelen bastırılıyor; başkası yazarsa uyarı
    // çıkmaya devam ediyor, yoksa haberin olmazdı.
    if (OpenChat.matches(message.title)) return;

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

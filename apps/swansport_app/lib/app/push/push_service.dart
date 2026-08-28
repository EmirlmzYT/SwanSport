import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

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
      'p256dh': sub.p256dh,
      'auth': sub.auth,
      if (userAgent != null) 'user_agent': userAgent,
    }, onConflict: 'endpoint');
  }

  Future<void> unregister(String endpoint) async {
    await _c.rpc<void>('drop_push_subscription',
        params: {'p_endpoint': endpoint});
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
  if (!pushSupported || !pushPermissionGranted) return;
  try {
    final sub = await pushCurrent() ?? await pushSubscribe();
    await ref.read(pushServiceProvider).register(sub);
  } catch (error) {
    // Sessiz tazeleme başarısız olursa kullanıcıyı rahatsız etme; ama izsiz
    // kalmasın — bildirimlerin neden gelmediği ancak buradan anlaşılır.
    debugPrint('SwanSport: push tazeleme başarısız — $error');
  }
}

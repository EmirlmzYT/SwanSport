import 'push_io.dart' if (dart.library.js_interop) 'push_web.dart' as impl;

/// Tarayıcıdan alınan push aboneliği.
class PushSub {
  const PushSub({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
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

/// Aboneliği tarayıcı tarafında iptal eder; iptal edilen adresi döner.
Future<String?> pushUnsubscribe() => impl.pushUnsubscribe();

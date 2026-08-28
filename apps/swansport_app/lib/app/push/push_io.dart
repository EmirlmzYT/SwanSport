import 'push.dart';

/// Web dışı platformlar: tarayıcı push'u yok.
///
/// Android/iOS uygulaması için ayrı bir sağlayıcı (FCM/APNs) gerekir; o gelene
/// kadar bu platformlarda bildirimler yalnızca uygulama içinde görünür.
bool get pushSupported => false;

bool get pushPermissionGranted => false;

Future<PushSub> pushSubscribe() async =>
    throw const PushException(PushFailure.unsupported);

Future<PushSub?> pushCurrent() async => null;

Future<String?> pushUnsubscribe() async => null;

import 'package:geolocator/geolocator.dart';

/// Konum alma — kortta olduğunu kanıtlamak için.
///
/// Yalnızca kullanıcı bir eylem yaparken çağrılır; arka planda konum
/// izlenmiyor. `image_pick.dart` ile aynı yaklaşım: hata sessizce yutulmaz,
/// çağıran tarafa neden söylenir ki kullanıcıya doğru cümle kurulabilsin.

/// Konumun alınamama nedeni.
enum PlaceFailure {
  /// Cihazın konum servisi kapalı (GPS kapalı).
  serviceOff,

  /// Kullanıcı izni reddetti.
  denied,

  /// Kullanıcı "bir daha sorma" dedi; ayarlardan açması gerekiyor.
  deniedForever,

  /// Sahte konum uygulaması tespit edildi.
  mocked,

  /// Konum alınamadı (sinyal yok, zaman aşımı).
  unavailable,
}

class PlaceException implements Exception {
  const PlaceException(this.reason);
  final PlaceFailure reason;

  /// Kullanıcıya gösterilecek cümle — ne olduğunu ve ne yapacağını söyler.
  String get message => switch (reason) {
        PlaceFailure.serviceOff =>
          'Telefonunun konum servisi kapalı. Açıp tekrar dene.',
        PlaceFailure.denied =>
          'Kortta olduğunu doğrulamak için konum izni gerekiyor.',
        PlaceFailure.deniedForever =>
          'Konum izni kapalı. Ayarlar > Uygulamalar > SwanSport üzerinden açabilirsin.',
        PlaceFailure.mocked =>
          'Sahte konum tespit edildi. Gerçekten kortta olman gerekiyor.',
        PlaceFailure.unavailable =>
          'Konum alınamadı. Açık alana çıkıp tekrar dene.',
      };

  @override
  String toString() => message;
}

/// Kullanıcının o anki konumu.
class Place {
  const Place({required this.lat, required this.lng, required this.accuracy});
  final double lat;
  final double lng;

  /// Metre cinsinden hata payı — büyükse kullanıcıyı uyarmak gerekebilir.
  final double accuracy;
}

/// Konumu alır; alınamazsa [PlaceException] fırlatır.
///
/// İzin akışı bilerek burada: her çağıran ayrı ayrı izin yönetmeye
/// kalkarsa biri unutur ve hata ancak sahada ortaya çıkar.
Future<Place> currentPlace() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const PlaceException(PlaceFailure.serviceOff);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const PlaceException(PlaceFailure.deniedForever);
  }
  if (permission == LocationPermission.denied) {
    throw const PlaceException(PlaceFailure.denied);
  }

  final Position position;
  try {
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  } catch (_) {
    throw const PlaceException(PlaceFailure.unavailable);
  }

  // Sahte konum uygulamaları Android'de yaygın. Bu kesin bir çözüm değil —
  // kararlı biri aşar — ama sıradan istismarı kesiyor. Gerçek çözüm korta
  // QR asmak olurdu; o da belediye görüşmesine bağlı.
  if (position.isMocked) {
    throw const PlaceException(PlaceFailure.mocked);
  }

  return Place(
    lat: position.latitude,
    lng: position.longitude,
    accuracy: position.accuracy,
  );
}

/// Konumu alır, alınamazsa null döner.
///
/// Yalnızca "yakındaki kortları önce göster" gibi süsleme işler için —
/// yetki kararı asla buna dayanmaz.
Future<Place?> currentPlaceOrNull() async {
  try {
    return await currentPlace();
  } catch (_) {
    return null;
  }
}

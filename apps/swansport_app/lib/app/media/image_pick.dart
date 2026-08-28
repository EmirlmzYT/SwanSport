import 'dart:typed_data';

import 'image_pick_io.dart' if (dart.library.js_interop) 'image_pick_web.dart'
    as impl;

/// Seçilen görselin baytları ve dosya adı.
class PickedImage {
  const PickedImage({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

/// Galeriden/dosyalardan tek bir görsel seçer.
///
/// Web'de tarayıcının kendi dosya girdisi kullanılır ve seçilen görsel
/// JPEG'e çevrilip küçültülür — böylece iPhone'un HEIC fotoğrafları da
/// çalışır (Flutter HEIC çözemez) ve yükleme çok daha hızlı olur.
/// Diğer platformlarda sistem dosya seçici kullanılır.
///
/// Kullanıcı vazgeçerse `null` döner.
Future<PickedImage?> pickImage() => impl.pickImage();

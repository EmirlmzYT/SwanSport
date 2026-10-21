import 'dart:typed_data';

import 'image_pick_io.dart' if (dart.library.js_interop) 'image_pick_web.dart'
    as impl;

/// Seçilen görselin baytları ve dosya adı.
class PickedImage {
  const PickedImage({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

enum ImagePickSource { gallery, camera }

/// UI içermeyen platform adaptörü. Mobilde sistem fotoğraf seçicisi kullanılır.
Future<List<PickedImage>> pickImages({
  ImagePickSource source = ImagePickSource.gallery,
  int limit = 1,
}) {
  if (limit < 1 || limit > 8) throw ArgumentError.value(limit, 'limit');
  return impl.pickImages(source: source, limit: limit);
}

/// Eski belge seçicilerinin tek görsel sözleşmesini korur.
Future<PickedImage?> pickImage() async {
  final images = await pickImages();
  return images.isEmpty ? null : images.first;
}

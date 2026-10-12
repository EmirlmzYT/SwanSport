import 'dart:typed_data';
import 'image_picker_stub.dart'
    if (dart.library.js_interop) 'image_picker_web.dart' as impl;

class PickedImageFile {
  const PickedImageFile({required this.bytes, required this.name, required this.mimeType});
  final Uint8List bytes;
  final String name;
  final String mimeType;
}
Future<PickedImageFile?> pickImageFile() => impl.pickImageFile();

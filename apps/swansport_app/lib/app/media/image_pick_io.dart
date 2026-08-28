import 'package:file_picker/file_picker.dart';

import 'image_pick.dart';

/// Mobil/masaüstü: sistem dosya seçici.
Future<PickedImage?> pickImage() async {
  final f = await FilePicker.pickFile(type: FileType.image);
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  return PickedImage(bytes: bytes, name: f.name);
}

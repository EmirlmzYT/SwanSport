import 'package:image_picker/image_picker.dart';

import 'image_pick.dart';

Future<List<PickedImage>> pickImages({
  required ImagePickSource source,
  required int limit,
}) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (source == ImagePickSource.gallery && limit > 1) {
    files = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      limit: limit,
      requestFullMetadata: false,
    );
  } else {
    final file = await picker.pickImage(
      source: source == ImagePickSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    files = file == null ? [] : [file];
  }
  final result = <PickedImage>[];
  // Bazı platformlar seçim sınırını uygulamaz; sunucu sınırına taşma olmasın.
  for (final file in files.take(limit)) {
    result.add(PickedImage(bytes: await file.readAsBytes(), name: file.name));
  }
  return result;
}

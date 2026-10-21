import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'image_pick.dart';

/// Yüklenen görselin en uzun kenarı bu değere indirilir (kalite/boyut dengesi).
const int _maxEdge = 1600;

/// JPEG sıkıştırma kalitesi.
const double _jpegQuality = 0.85;

/// Web: tarayıcının kendi dosya girdisi + tuval ile JPEG'e çevirme.
///
/// `accept` içinde bilerek HEIC yok — iOS Safari, kabul edilen türler arasında
/// HEIC görmeyince fotoğrafı otomatik olarak JPEG'e çevirerek verir. Ayrıca
/// seçilen her görsel tuvale çizilip yeniden JPEG olarak kodlanır; bu hem
/// biçim sorunlarını bitirir hem de dosya boyutunu ciddi şekilde düşürür.
Future<List<PickedImage>> pickImages({
  required ImagePickSource source,
  required int limit,
}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp'
    ..multiple = source == ImagePickSource.gallery && limit > 1
    ..style.display = 'none';
  if (source == ImagePickSource.camera) {
    input.setAttribute('capture', 'environment');
  }
  web.document.body?.append(input);
  final completer = Completer<List<PickedImage>>();
  void finish(List<PickedImage> images) {
    if (!completer.isCompleted) completer.complete(images);
    input.remove();
  }

  Future<void> readSelection() async {
    try {
      final files = input.files;
      final images = <PickedImage>[];
      if (files != null) {
        for (var i = 0; i < files.length && i < limit; i++) {
          final file = files.item(i);
          if (file != null) images.add(await _toJpeg(file));
        }
      }
      finish(images);
    } catch (error, stack) {
      input.remove();
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
  }

  input.addEventListener(
    'change',
    ((web.Event _) => unawaited(readSelection())).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish([])).toJS);
  // click, kaynak satırına dokunulan aynı kullanıcı olayında çalışır.
  input.click();
  return completer.future;
}

/// Dosyayı tuvale çizip JPEG olarak yeniden kodlar ve küçültür.
Future<PickedImage> _toJpeg(web.File file) async {
  final url = web.URL.createObjectURL(file);
  try {
    final img = web.HTMLImageElement()..src = url;
    await img.decode().toDart;

    var w = img.naturalWidth;
    var h = img.naturalHeight;
    if (w <= 0 || h <= 0) throw StateError('Görsel boyutu okunamadı');

    // En uzun kenarı sınırla, oranı koru.
    if (w > _maxEdge || h > _maxEdge) {
      if (w >= h) {
        h = (h * _maxEdge / w).round();
        w = _maxEdge;
      } else {
        w = (w * _maxEdge / h).round();
        h = _maxEdge;
      }
    }

    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) throw StateError('Tuval oluşturulamadı');
    ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());

    final dataUrl = canvas.toDataURL('image/jpeg', _jpegQuality.toJS);
    final comma = dataUrl.indexOf(',');
    if (comma < 0 || !dataUrl.startsWith('data:image/jpeg')) {
      throw StateError('JPEG kodlanamadı');
    }
    final bytes = base64Decode(dataUrl.substring(comma + 1));

    return PickedImage(bytes: bytes, name: _jpegName(file.name));
  } finally {
    web.URL.revokeObjectURL(url);
  }
}

String _jpegName(String original) {
  final dot = original.lastIndexOf('.');
  final base = dot > 0 ? original.substring(0, dot) : original;
  return '${base.isEmpty ? 'gorsel' : base}.jpg';
}

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

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
Future<PickedImage?> pickImage() async {
  final input =
      web.document.createElement('input') as web.HTMLInputElement
        ..type = 'file'
        ..accept = 'image/jpeg,image/png,image/webp'
        ..multiple = false
        ..style.display = 'none';

  web.document.body?.append(input);

  final completer = Completer<PickedImage?>();

  void finish(PickedImage? result) {
    if (!completer.isCompleted) completer.complete(result);
    input.remove();
  }

  // NOT: `toJS` yalnızca void dönen işlevleri kabul eder; bu yüzden dinleyici
  // eşzamanlı, asıl iş ayrı bir async işlevde yapılır.
  Future<void> handleFile(web.File file) async {
    try {
      finish(await _toJpeg(file));
    } catch (_) {
      // Dönüştürme başarısızsa ham baytlarla devam et.
      try {
        final bytes = await _readBytes(file);
        finish(PickedImage(bytes: bytes, name: file.name));
      } catch (_) {
        finish(null);
      }
    }
  }

  void onChange(web.Event _) {
    final files = input.files;
    final file = (files == null || files.length == 0) ? null : files.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    unawaited(handleFile(file));
  }

  input.addEventListener('change', onChange.toJS);

  // Kullanıcı vazgeçerse (destekleyen tarayıcılarda) beklemede kalmayalım.
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);

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

Future<Uint8List> _readBytes(web.File file) {
  final completer = Completer<Uint8List>();
  final reader = web.FileReader();
  reader.addEventListener(
    'loadend',
    ((web.Event _) {
      final buffer = (reader.result as JSArrayBuffer?)?.toDart;
      if (buffer == null) {
        completer.completeError(StateError('Dosya okunamadı'));
      } else {
        completer.complete(buffer.asUint8List());
      }
    }).toJS,
  );
  reader.addEventListener(
    'error',
    ((web.Event _) => completer.completeError(StateError('Dosya okunamadı')))
        .toJS,
  );
  reader.readAsArrayBuffer(file);
  return completer.future;
}

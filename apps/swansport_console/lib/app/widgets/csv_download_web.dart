import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Metni tarayıcıda dosya olarak indirir.
///
/// Blob + geçici bağlantı: sunucuya uğramadan, istemcideki veriden dosya
/// üretir. URL hemen serbest bırakılır, yoksa sekme kapanana kadar bellekte
/// kalır.
void saveTextFile({
  required String fileName,
  required String text,
  required String mimeType,
}) {
  final bytes = utf8.encode(text);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );

  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
